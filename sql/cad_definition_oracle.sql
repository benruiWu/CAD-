-- CAD Precision Definition Script for Oracle Database
-- This script consolidates diagnostic evidence across multiple clinical data sources
-- to identify patients with Coronary Artery Disease (CAD).
-- 数据源包括：住院和门诊诊断、介入和手术操作记录、用药、化验和影像报告。

-- 1. 患者基本信息（可替换为真实患者维表）
WITH patient_base AS (
    SELECT DISTINCT
        p.patient_id,
        p.gender,
        p.birth_date
    FROM dim_patient p
),

-- 2. 诊断信息：门急诊与住院诊断 ICD10 代码
--   以 I20-I25 系列为 CAD 相关编码，可根据医院编码体系扩展
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

-- 4. 用药信息：心绞痛、抗血小板及他汀类等慢性 CAD 治疗药物
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

-- 5. 实验室检查：高敏肌钙蛋白、肌酸激酶同工酶等冠心病相关指标
lab_evidence AS (
    SELECT DISTINCT
        l.patient_id,
        l.encounter_id,
        l.test_code,
        l.test_date,
        l.result_value
    FROM fact_lab_result l
    WHERE l.test_code IN ('CKMB', 'TROPONIN_I', 'TROPONIN_T')
        AND l.result_value > l.upper_limit  -- 异常升高
),

-- 6. 影像报告：冠状动脉造影、CT、核医学显像
imaging_evidence AS (
    SELECT DISTINCT
        img.patient_id,
        img.encounter_id,
        img.report_type,
        img.report_date
    FROM fact_imaging_report img
    WHERE img.report_type IN ('CORONARY_ANGIOGRAPHY', 'CARDIAC_CT', 'MYOCARDIAL_PET')
),

-- 7. 综合证据表：合并所有来源并添加证据类型标签
combined_evidence AS (
    SELECT patient_id, encounter_id, diagnosis_date AS evidence_date,
           'DIAGNOSIS' AS evidence_type, diagnosis_code AS evidence_code
    FROM encounter_diagnoses
    UNION ALL
    SELECT patient_id, encounter_id, procedure_date, 'PROCEDURE', procedure_code
    FROM procedure_evidence
    UNION ALL
    SELECT patient_id, encounter_id, start_date, 'MEDICATION', medication_code
    FROM medication_evidence
    UNION ALL
    SELECT patient_id, encounter_id, test_date, 'LAB', test_code
    FROM lab_evidence
    UNION ALL
    SELECT patient_id, encounter_id, report_date, 'IMAGING', report_type
    FROM imaging_evidence
),

-- 8. 证据评分：根据证据类型赋分，用于量化判断
scored_evidence AS (
    SELECT
        ce.patient_id,
        ce.encounter_id,
        ce.evidence_type,
        ce.evidence_code,
        ce.evidence_date,
        CASE ce.evidence_type
            WHEN 'DIAGNOSIS' THEN 3
            WHEN 'PROCEDURE' THEN 5
            WHEN 'LAB' THEN 2
            WHEN 'IMAGING' THEN 4
            WHEN 'MEDICATION' THEN 1
            ELSE 0
        END AS evidence_score
    FROM combined_evidence ce
),

-- 9. 患者级别的综合评分与首次确诊日期
patient_cad_summary AS (
    SELECT
        se.patient_id,
        MIN(se.evidence_date) AS first_cad_date,
        SUM(se.evidence_score) AS total_score,
        COUNT(DISTINCT se.evidence_type) AS evidence_types
    FROM scored_evidence se
    GROUP BY se.patient_id
)

-- 10. 输出结果：筛选满足定义的 CAD 患者
SELECT
    pb.patient_id,
    pb.gender,
    pb.birth_date,
    pcs.first_cad_date,
    pcs.total_score,
    pcs.evidence_types,
    CASE
        WHEN pcs.total_score >= 8 AND pcs.evidence_types >= 2 THEN 'CONFIRMED_CAD'
        WHEN pcs.total_score BETWEEN 5 AND 7 THEN 'PROBABLE_CAD'
        ELSE 'REVIEW_REQUIRED'
    END AS cad_classification
FROM patient_cad_summary pcs
JOIN patient_base pb ON pb.patient_id = pcs.patient_id
ORDER BY pcs.total_score DESC;
