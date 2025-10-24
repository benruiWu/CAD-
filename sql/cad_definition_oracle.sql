-- CAD Precision Definition Script for Oracle Database
-- This script consolidates diagnostic evidence across multiple clinical data sources
-- to identify patients with Coronary Artery Disease (CAD).
-- 数据源包括：手术史、用药、化验、影像、心电图、症状及慢病史。

WITH patient_base AS (
    SELECT DISTINCT
        p.patient_id,
        p.gender,
        p.birth_date
    FROM dim_patient p
),

-- 0. 心肌损伤标志物原始检测明细（CK-MB / 肌钙蛋白）
tnc_test AS (
    SELECT *
    FROM KSRAWDATA_2024_08.Z01_HOS_TESTDETAILS
    WHERE EX_PROJ_NAME LIKE '%CK-MB%'
       OR (EX_PROJ_NAME LIKE '%肌酸激酶%' AND EX_PROJ_NAME LIKE '%同工酶%')
       OR EX_PROJ_NAME LIKE '%肌钙蛋白%'
       OR EX_PROJ_NAME LIKE '%cTn%'
       OR EX_PROJ_NAME LIKE '%TnC%'
       OR EX_PROJ_NAME LIKE '%TnI%'
       OR EX_PROJ_NAME LIKE '%TnL%'
       OR EX_PROJ_NAME LIKE '%TnT%'
       OR EX_PROJ_NAME LIKE '%Troponin%'
),

-- 心肌损伤检测阳性判断（保留阳性记录）
tnc_positive_results AS (
    SELECT
        t.*,
        CASE
            WHEN t.NO_RPT LIKE '%<%' THEN 0
            WHEN t.NO_RPT LIKE '%>%' THEN 1
            WHEN REGEXP_LIKE(t.NO_RPT, '^[0-9]+(\.[0-9]+)?$')
                 AND TO_NUMBER(REGEXP_SUBSTR(t.NO_RPT, '[0-9]+(\.[0-9]+)?')) > t.UNL THEN 1
            WHEN REGEXP_SUBSTR(t.NO_RPT, '[0-9]+(\.[0-9]+)?') IS NOT NULL
                 AND TO_NUMBER(REGEXP_SUBSTR(t.NO_RPT, '[0-9]+(\.[0-9]+)?')) > t.UNL THEN 1
            WHEN t.NO_RPT LIKE '%阳性%' THEN 1
            ELSE 0
        END AS positive_flag,
        CASE
            WHEN REGEXP_SUBSTR(t.NO_RPT, '[0-9]+(\.[0-9]+)?') IS NOT NULL
                 THEN TO_NUMBER(REGEXP_SUBSTR(t.NO_RPT, '[0-9]+(\.[0-9]+)?'))
        END AS numeric_result
    FROM tnc_test t
),

-- 1. 介入与手术操作记录：如 PCI、CABG
procedure_evidence AS (
    SELECT DISTINCT
        op.patient_id,
        op.encounter_id,
        op.procedure_code,
        op.procedure_date
    FROM fact_procedure op
    WHERE op.procedure_code IN (
        'PCI',
        '0210093',
        '0211093'
    )
),

-- 2. 冠脉造影：仅保留狭窄程度 >50%
angiography_evidence AS (
    SELECT DISTINCT
        img.patient_id,
        img.encounter_id,
        img.report_date,
        img.stenosis_percent
    FROM fact_imaging_report img
    WHERE img.report_type = 'CORONARY_ANGIOGRAPHY'
      AND NVL(img.stenosis_percent, 0) > 50
),

-- 3. 冠脉 CTA：筛选中度及以上狭窄
cta_evidence AS (
    SELECT DISTINCT
        img.patient_id,
        img.encounter_id,
        img.report_date,
        COALESCE(img.stenosis_percent,
                 CASE img.stenosis_grade
                     WHEN 'MODERATE' THEN 60
                     WHEN 'SEVERE' THEN 80
                     ELSE NULL
                 END) AS stenosis_percent
    FROM fact_imaging_report img
    WHERE img.report_type = 'CORONARY_CTA'
      AND (
          NVL(img.stenosis_percent, 0) >= 50
          OR img.stenosis_grade IN ('MODERATE', 'SEVERE')
      )
),

-- 4. 心肌损伤标志物
lab_biomarker_evidence AS (
    SELECT DISTINCT
        t.PATIENT_ID AS patient_id,
        t.VISIT_ID AS encounter_id,
        t.EX_PROJ_NAME AS test_code,
        t.REPORT_TIME AS test_date,
        NVL(t.numeric_result, t.UNL) AS result_value
    FROM tnc_positive_results t
    WHERE t.positive_flag = 1
),

-- 5. 双联抗血小板治疗：同一次就诊至少两种抗板药。
--    由于强化抗板方案伴随较高出血风险，通常仅在确诊或高度怀疑急性心梗时实施，可视为金标准证据。
dual_antiplatelet_therapy AS (
    SELECT
        m.patient_id,
        m.encounter_id,
        MIN(m.start_date) AS therapy_start_date
    FROM fact_medication m
    WHERE m.medication_code IN (
        'ATC-B01AC04', -- 阿司匹林
        'ATC-B01AC05', -- 氯吡格雷
        'ATC-B01AC24', -- 替格瑞洛
        'ATC-B01AC30'  -- 普拉格雷
    )
    GROUP BY m.patient_id, m.encounter_id
    HAVING COUNT(DISTINCT m.medication_code) >= 2
),

-- 6. 长期抗血小板治疗：单药持续用药 >=90 天。
--    持续维持抗板药物代表医生在权衡出血风险后仍需持续预防，提示既往事件或高度风险。
long_term_antiplatelet AS (
    SELECT DISTINCT
        m.patient_id,
        m.encounter_id,
        m.start_date,
        m.days_supply
    FROM fact_medication m
    WHERE m.medication_code IN (
        'ATC-B01AC04',
        'ATC-B01AC05',
        'ATC-B01AC24',
        'ATC-B01AC30'
    )
      AND NVL(m.days_supply, 0) >= 90
      AND NOT EXISTS (
          SELECT 1
          FROM dual_antiplatelet_therapy dapt
          WHERE dapt.patient_id = m.patient_id
            AND dapt.encounter_id = m.encounter_id
      )
),

-- 7. 其他 CAD 相关维持治疗药物
cad_maintenance_medications AS (
    SELECT DISTINCT
        m.patient_id,
        m.encounter_id,
        m.medication_code,
        m.start_date
    FROM fact_medication m
    WHERE m.medication_code IN (
        'ATC-C01DA02', -- 硝酸甘油
        'ATC-C10AA05'  -- 阿托伐他汀
    )
),

-- 8. 心电图证据：ST 段改变、病理性 Q 波
ecg_evidence AS (
    SELECT DISTINCT
        ecg.patient_id,
        ecg.encounter_id,
        ecg.ecg_code,
        ecg.ecg_date
    FROM fact_ecg_result ecg
    WHERE ecg.ecg_code IN (
        'ECG_ST_ELEVATION',
        'ECG_ST_DEPRESSION',
        'ECG_PATHOLOGIC_Q'
    )
),

-- 9. 症状：特异性与非特异性区分
specific_symptom_evidence AS (
    SELECT DISTINCT
        s.patient_id,
        s.encounter_id,
        s.symptom_code,
        s.symptom_date
    FROM fact_encounter_symptom s
    WHERE s.symptom_code IN (
        'TYPICAL_ANGINA',           -- 劳力或静息诱发的典型压榨性胸痛
        'REST_CHEST_PAIN',          -- 静息胸痛持续 ≥20 分钟
        'ANGINA_EQUIVALENT',        -- 心绞痛等效症状
        'CHEST_PAIN_RADIATING',     -- 胸痛向左上肢、下颌或背部放射
        'CHEST_PAIN_WITH_DIAPHORESIS' -- 胸痛伴冷汗/恶心呕吐
    )
),

general_symptom_evidence AS (
    SELECT DISTINCT
        s.patient_id,
        s.encounter_id,
        s.symptom_code,
        s.symptom_date
    FROM fact_encounter_symptom s
    WHERE s.symptom_code IN (
        'CHEST_TIGHTNESS',
        'DYSPNEA',
        'EPIGASTRIC_DISCOMFORT',
        'FATIGUE'
    )
),

-- 10. 慢病史：高血压、糖尿病、血脂异常
chronic_condition_history AS (
    SELECT DISTINCT
        c.patient_id,
        c.condition_code,
        c.record_date
    FROM fact_chronic_condition c
    WHERE c.condition_code IN (
        'HYPERTENSION',
        'DIABETES',
        'HYPERLIPIDEMIA'
    )
),

-- 11. 综合证据表：合并所有来源并添加证据类型与数值
combined_evidence AS (
    SELECT patient_id,
           encounter_id,
           procedure_date AS evidence_date,
           'PROCEDURE' AS evidence_type,
           procedure_code AS evidence_code,
           NULL AS evidence_numeric
    FROM procedure_evidence

    UNION ALL

    SELECT patient_id,
           encounter_id,
           report_date,
           'IMAGING' AS evidence_type,
           'CORONARY_ANGIOGRAPHY' AS evidence_code,
           stenosis_percent AS evidence_numeric
    FROM angiography_evidence

    UNION ALL

    SELECT patient_id,
           encounter_id,
           report_date,
           'IMAGING' AS evidence_type,
           'CORONARY_CTA' AS evidence_code,
           stenosis_percent AS evidence_numeric
    FROM cta_evidence

    UNION ALL

    SELECT patient_id,
           encounter_id,
           test_date,
           'LAB' AS evidence_type,
           test_code AS evidence_code,
           result_value AS evidence_numeric
    FROM lab_biomarker_evidence

    UNION ALL

    SELECT patient_id,
           encounter_id,
           therapy_start_date,
           'MEDICATION' AS evidence_type,
           'DUAL_ANTIPLATELET' AS evidence_code,
           NULL AS evidence_numeric
    FROM dual_antiplatelet_therapy

    UNION ALL

    SELECT patient_id,
           encounter_id,
           start_date,
           'MEDICATION' AS evidence_type,
           'LONG_TERM_ANTIPLATELET' AS evidence_code,
           days_supply AS evidence_numeric
    FROM long_term_antiplatelet

    UNION ALL

    SELECT patient_id,
           encounter_id,
           start_date,
           'MEDICATION' AS evidence_type,
           medication_code AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_maintenance_medications

    UNION ALL

    SELECT patient_id,
           encounter_id,
           ecg_date,
           'ECG' AS evidence_type,
           ecg_code AS evidence_code,
           NULL AS evidence_numeric
    FROM ecg_evidence

    UNION ALL

    SELECT patient_id,
           encounter_id,
           symptom_date,
           'SYMPTOM' AS evidence_type,
           symptom_code AS evidence_code,
           NULL AS evidence_numeric
    FROM specific_symptom_evidence

    UNION ALL

    SELECT patient_id,
           encounter_id,
           symptom_date,
           'SYMPTOM' AS evidence_type,
           symptom_code AS evidence_code,
           NULL AS evidence_numeric
    FROM general_symptom_evidence

    UNION ALL

    SELECT patient_id,
           NULL AS encounter_id,
           record_date,
           'CHRONIC_CONDITION' AS evidence_type,
           condition_code AS evidence_code,
           NULL AS evidence_numeric
    FROM chronic_condition_history
),

-- 12. 证据分类与评分
classified_evidence AS (
    SELECT
        ce.patient_id,
        ce.encounter_id,
        ce.evidence_type,
        ce.evidence_code,
        ce.evidence_date,
        ce.evidence_numeric,
        CASE
            WHEN ce.evidence_type = 'IMAGING'
                 AND ce.evidence_code = 'CORONARY_ANGIOGRAPHY'
                 AND NVL(ce.evidence_numeric, 0) > 50 THEN 'GOLD_STANDARD'
            WHEN ce.evidence_type = 'LAB' THEN 'GOLD_STANDARD'
            WHEN ce.evidence_type = 'PROCEDURE' THEN 'GOLD_STANDARD'
            WHEN ce.evidence_type = 'MEDICATION' AND ce.evidence_code = 'DUAL_ANTIPLATELET' THEN 'GOLD_STANDARD'
            WHEN ce.evidence_type = 'IMAGING' AND ce.evidence_code = 'CORONARY_CTA' THEN 'STRONG'
            WHEN ce.evidence_type = 'MEDICATION' AND ce.evidence_code = 'LONG_TERM_ANTIPLATELET' THEN 'STRONG'
            WHEN ce.evidence_type = 'ECG' THEN 'STRONG'
            WHEN ce.evidence_type = 'SYMPTOM'
                 AND ce.evidence_code IN (
                     'TYPICAL_ANGINA',
                     'REST_CHEST_PAIN',
                     'ANGINA_EQUIVALENT',
                     'CHEST_PAIN_RADIATING',
                     'CHEST_PAIN_WITH_DIAPHORESIS'
                 ) THEN 'STRONG'
            WHEN ce.evidence_type = 'SYMPTOM' THEN 'MODERATE'
            WHEN ce.evidence_type = 'MEDICATION' THEN 'MODERATE'
            WHEN ce.evidence_type = 'CHRONIC_CONDITION' THEN 'WEAK'
            ELSE 'WEAK'
        END AS evidence_category,
        CASE
            WHEN ce.evidence_type = 'IMAGING'
                 AND ce.evidence_code = 'CORONARY_ANGIOGRAPHY'
                 AND NVL(ce.evidence_numeric, 0) > 50 THEN 6
            WHEN ce.evidence_type = 'LAB' THEN 6
            WHEN ce.evidence_type = 'PROCEDURE' THEN 6
            WHEN ce.evidence_type = 'MEDICATION' AND ce.evidence_code = 'DUAL_ANTIPLATELET' THEN 6
            WHEN ce.evidence_type = 'IMAGING' AND ce.evidence_code = 'CORONARY_CTA' THEN 4
            WHEN ce.evidence_type = 'MEDICATION' AND ce.evidence_code = 'LONG_TERM_ANTIPLATELET' THEN 4
            WHEN ce.evidence_type = 'ECG' THEN 4
            WHEN ce.evidence_type = 'SYMPTOM'
                 AND ce.evidence_code IN (
                     'TYPICAL_ANGINA',
                     'REST_CHEST_PAIN',
                     'ANGINA_EQUIVALENT',
                     'CHEST_PAIN_RADIATING',
                     'CHEST_PAIN_WITH_DIAPHORESIS'
                 ) THEN 4
            WHEN ce.evidence_type = 'SYMPTOM' THEN 2
            WHEN ce.evidence_type = 'MEDICATION' THEN 2
            WHEN ce.evidence_type = 'CHRONIC_CONDITION' THEN 1
            ELSE 1
        END AS evidence_score
    FROM combined_evidence ce
),

-- 13. 患者级别的综合评分与首次证据分类统计
patient_cad_summary AS (
    SELECT
        se.patient_id,
        MIN(se.evidence_date) AS first_cad_date,
        SUM(se.evidence_score) AS total_score,
        COUNT(DISTINCT se.evidence_type) AS evidence_types,
        SUM(CASE WHEN se.evidence_category = 'GOLD_STANDARD' THEN 1 ELSE 0 END) AS gold_evidence_count,
        SUM(CASE WHEN se.evidence_category = 'STRONG' THEN 1 ELSE 0 END) AS strong_evidence_count,
        SUM(CASE WHEN se.evidence_category = 'MODERATE' THEN 1 ELSE 0 END) AS moderate_evidence_count,
        SUM(CASE WHEN se.evidence_category = 'WEAK' THEN 1 ELSE 0 END) AS weak_evidence_count
    FROM classified_evidence se
    GROUP BY se.patient_id
)

-- 14. 输出结果：展示证据梯度与最终分类
SELECT
    pb.patient_id,
    pb.gender,
    pb.birth_date,
    pcs.first_cad_date,
    pcs.total_score,
    pcs.evidence_types,
    pcs.gold_evidence_count,
    pcs.strong_evidence_count,
    pcs.moderate_evidence_count,
    pcs.weak_evidence_count,
    CASE
        WHEN pcs.gold_evidence_count >= 1 THEN 'CONFIRMED_CAD'
        WHEN pcs.strong_evidence_count >= 2
             OR (pcs.strong_evidence_count >= 1 AND pcs.moderate_evidence_count >= 2) THEN 'HIGH_PROBABILITY_CAD'
        WHEN pcs.moderate_evidence_count >= 2 AND pcs.total_score >= 6 THEN 'POSSIBLE_CAD'
        ELSE 'REVIEW_REQUIRED'
    END AS cad_classification
FROM patient_cad_summary pcs
JOIN patient_base pb ON pb.patient_id = pcs.patient_id
ORDER BY pcs.total_score DESC;
