-- CAD Precision Definition Script for Oracle Database
-- This script consolidates diagnostic evidence across multiple clinical data sources
-- to identify patients with Coronary Artery Disease (CAD).
-- 数据源包括：诊断、手术史、用药、化验、影像、心电图、症状及慢病史。

-- 1. 患者基本信息（可替换为真实患者维表）
WITH patient_base AS (
    SELECT DISTINCT
        p.patient_id,
        p.gender,
        p.birth_date
    FROM dim_patient p
),

-- 2. 诊断信息：门急诊与住院诊断 ICD10 代码
--   I20-I25 系列为 CAD 相关编码，可根据医院编码体系扩展
encounter_diagnoses AS (
    SELECT DISTINCT
        d.patient_id,
        d.encounter_id,
        d.encounter_type,
        d.diagnosis_code,
        d.diagnosis_date
    FROM fact_diagnosis d
    WHERE d.diagnosis_code BETWEEN 'I20' AND 'I2599'
),

-- 3. 介入与手术操作记录：如 PCI、CABG
procedure_evidence AS (
    SELECT DISTINCT
        op.patient_id,
        op.encounter_id,
        op.procedure_code,
        op.procedure_date
    FROM fact_procedure op
    WHERE op.procedure_code IN (
        'PCI',          -- 经皮冠状动脉介入治疗
        '0210093',      -- 示例：CABG ICD-10-PCS
        '0211093'
    )
),

-- 4. 心电图证据：ST 段改变、病理性 Q 波等
ecg_evidence AS (
    SELECT DISTINCT
        ecg.patient_id,
        ecg.encounter_id,
        ecg.ecg_code,
        ecg.ecg_date
    FROM fact_ecg_result ecg
    WHERE ecg.ecg_code IN (
        'ECG_ST_ELEVATION',   -- ST 段抬高
        'ECG_ST_DEPRESSION',  -- ST 段压低
        'ECG_PATHOLOGIC_Q'    -- 病理性 Q 波
    )
),

-- 5. 用药信息：心绞痛、抗血小板及他汀类等慢性 CAD 治疗药物
medication_evidence AS (
    SELECT DISTINCT
        m.patient_id,
        m.encounter_id,
        m.medication_code,
        m.start_date
    FROM fact_medication m
    WHERE m.medication_code IN (
        'ATC-C01DA02',  -- 硝酸甘油
        'ATC-B01AC04',  -- 阿司匹林
        'ATC-C10AA05'   -- 阿托伐他汀
    )
),

-- 6. 就诊症状：胸痛、胸闷等典型症状
symptom_evidence AS (
    SELECT DISTINCT
        s.patient_id,
        s.encounter_id,
        s.symptom_code,
        s.symptom_date
    FROM fact_encounter_symptom s
    WHERE s.symptom_code IN (
        'CHEST_PAIN',
        'CHEST_TIGHTNESS',
        'DYSPNEA'
    )
),

-- 7. 实验室检查：心肌损伤标志物
lab_evidence AS (
    SELECT DISTINCT
        l.patient_id,
        l.encounter_id,
        l.test_code,
        l.test_date,
        l.result_value
    FROM fact_lab_result l
    WHERE l.test_code IN ('CKMB', 'TROPONIN_I', 'TROPONIN_T')
        AND l.result_value > l.upper_limit
),

-- 8. 影像报告：冠状动脉造影、CT、核医学显像
imaging_evidence AS (
    SELECT DISTINCT
        img.patient_id,
        img.encounter_id,
        img.report_type,
        img.report_date
    FROM fact_imaging_report img
    WHERE img.report_type IN ('CORONARY_ANGIOGRAPHY', 'CARDIAC_CT', 'MYOCARDIAL_PET')
),

-- 9. 慢病史：高血压、糖尿病、血脂异常等
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

-- 10. 综合证据表：合并所有来源并添加证据类型标签
combined_evidence AS (
    SELECT patient_id, encounter_id, diagnosis_date AS evidence_date,
           'DIAGNOSIS' AS evidence_type, diagnosis_code AS evidence_code
    FROM encounter_diagnoses
    UNION ALL
    SELECT patient_id, encounter_id, procedure_date, 'PROCEDURE', procedure_code
    FROM procedure_evidence
    UNION ALL
    SELECT patient_id, encounter_id, ecg_date, 'ECG', ecg_code
    FROM ecg_evidence
    UNION ALL
    SELECT patient_id, encounter_id, start_date, 'MEDICATION', medication_code
    FROM medication_evidence
    UNION ALL
    SELECT patient_id, encounter_id, symptom_date, 'SYMPTOM', symptom_code
    FROM symptom_evidence
    UNION ALL
    SELECT patient_id, encounter_id, test_date, 'LAB', test_code
    FROM lab_evidence
    UNION ALL
    SELECT patient_id, encounter_id, report_date, 'IMAGING', report_type
    FROM imaging_evidence
    UNION ALL
    SELECT patient_id, NULL AS encounter_id, record_date, 'CHRONIC_CONDITION', condition_code
    FROM chronic_condition_history
),

-- 11. 证据分类与评分：区分金标准、强、中、弱证据
classified_evidence AS (
    SELECT
        ce.patient_id,
        ce.encounter_id,
        ce.evidence_type,
        ce.evidence_code,
        ce.evidence_date,
        CASE
            WHEN ce.evidence_type = 'PROCEDURE' AND ce.evidence_code = 'PCI' THEN 'GOLD_STANDARD'
            WHEN ce.evidence_type = 'IMAGING' AND ce.evidence_code = 'CORONARY_ANGIOGRAPHY' THEN 'GOLD_STANDARD'
            WHEN ce.evidence_type = 'LAB' THEN 'STRONG'
            WHEN ce.evidence_type = 'ECG' THEN 'STRONG'
            WHEN ce.evidence_type = 'DIAGNOSIS' AND ce.evidence_code BETWEEN 'I21' AND 'I2199' THEN 'STRONG'
            WHEN ce.evidence_type = 'MEDICATION' THEN 'MODERATE'
            WHEN ce.evidence_type = 'SYMPTOM' THEN 'MODERATE'
            WHEN ce.evidence_type = 'DIAGNOSIS' THEN 'MODERATE'
            WHEN ce.evidence_type = 'CHRONIC_CONDITION' THEN 'WEAK'
            ELSE 'WEAK'
        END AS evidence_category,
        CASE
            WHEN ce.evidence_type = 'PROCEDURE' AND ce.evidence_code = 'PCI' THEN 6
            WHEN ce.evidence_type = 'IMAGING' AND ce.evidence_code = 'CORONARY_ANGIOGRAPHY' THEN 6
            WHEN ce.evidence_type = 'LAB' THEN 4
            WHEN ce.evidence_type = 'ECG' THEN 4
            WHEN ce.evidence_type = 'DIAGNOSIS' AND ce.evidence_code BETWEEN 'I21' AND 'I2199' THEN 4
            WHEN ce.evidence_type = 'MEDICATION' THEN 2
            WHEN ce.evidence_type = 'SYMPTOM' THEN 2
            WHEN ce.evidence_type = 'DIAGNOSIS' THEN 2
            WHEN ce.evidence_type = 'CHRONIC_CONDITION' THEN 1
            ELSE 1
        END AS evidence_score
    FROM combined_evidence ce
),

-- 12. 患者级别的综合评分与首次证据分类统计
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

-- 13. 输出结果：展示证据梯度与最终分类
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
        WHEN pcs.strong_evidence_count >= 2 OR (pcs.strong_evidence_count >= 1 AND pcs.moderate_evidence_count >= 2) THEN 'HIGH_PROBABILITY_CAD'
        WHEN pcs.moderate_evidence_count >= 2 AND pcs.total_score >= 6 THEN 'POSSIBLE_CAD'
        ELSE 'REVIEW_REQUIRED'
    END AS cad_classification
FROM patient_cad_summary pcs
JOIN patient_base pb ON pb.patient_id = pcs.patient_id
ORDER BY pcs.total_score DESC;
