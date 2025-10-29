-- CAD Precision Definition Script for Oracle Database
-- This script consolidates diagnostic evidence across multiple clinical data sources
-- to identify patients with Coronary Artery Disease (CAD).
-- 数据源包括：手术史、用药、化验、影像、心电图、症状及慢病史。

WITH patient_base AS (
    SELECT DISTINCT
        p.GLOBAL_INDEX AS GLOBAL_INDEX,
        p.gender,
        p.birth_date
    FROM dim_patient p
),

combined_evidence AS (
    SELECT GLOBAL_INDEX,
           encounter_id,
           procedure_date AS evidence_date,
           'PROCEDURE' AS evidence_type,
           procedure_code AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_procedure_evidence

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           report_date AS evidence_date,
           'IMAGING' AS evidence_type,
           'CORONARY_ANGIOGRAPHY' AS evidence_code,
           stenosis_percent AS evidence_numeric
    FROM cad_angiography_evidence

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           report_date AS evidence_date,
           'IMAGING' AS evidence_type,
           'CORONARY_CTA' AS evidence_code,
           stenosis_percent AS evidence_numeric
    FROM cad_cta_evidence

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           test_date AS evidence_date,
           'LAB' AS evidence_type,
           test_code AS evidence_code,
           result_value AS evidence_numeric
    FROM cad_lab_biomarker_evidence

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           therapy_start_date AS evidence_date,
           'MEDICATION' AS evidence_type,
           'DUAL_ANTIPLATELET' AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_dual_antiplatelet_therapy

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           therapy_start_date AS evidence_date,
           'MEDICATION' AS evidence_type,
           'LONG_TERM_ANTIPLATELET' AS evidence_code,
           therapy_months AS evidence_numeric
    FROM cad_long_term_antiplatelet

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           start_date AS evidence_date,
           'MEDICATION' AS evidence_type,
           medication_code AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_maintenance_medications

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           ecg_date AS evidence_date,
           'ECG' AS evidence_type,
           ecg_code AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_ecg_evidence

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           symptom_date AS evidence_date,
           'SYMPTOM' AS evidence_type,
           symptom_code AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_specific_symptom_evidence

    UNION ALL

    SELECT GLOBAL_INDEX,
           encounter_id,
           symptom_date AS evidence_date,
           'SYMPTOM' AS evidence_type,
           symptom_code AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_general_symptom_evidence

    UNION ALL

    SELECT GLOBAL_INDEX,
           NULL AS encounter_id,
           record_date AS evidence_date,
           'CHRONIC_CONDITION' AS evidence_type,
           condition_code AS evidence_code,
           NULL AS evidence_numeric
    FROM cad_chronic_condition_history
),

classified_evidence AS (
    SELECT
        ce.GLOBAL_INDEX,
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

patient_cad_summary AS (
    SELECT
        se.GLOBAL_INDEX,
        MIN(se.evidence_date) AS first_cad_date,
        SUM(se.evidence_score) AS total_score,
        COUNT(DISTINCT se.evidence_type) AS evidence_types,
        SUM(CASE WHEN se.evidence_category = 'GOLD_STANDARD' THEN 1 ELSE 0 END) AS gold_evidence_count,
        SUM(CASE WHEN se.evidence_category = 'STRONG' THEN 1 ELSE 0 END) AS strong_evidence_count,
        SUM(CASE WHEN se.evidence_category = 'MODERATE' THEN 1 ELSE 0 END) AS moderate_evidence_count,
        SUM(CASE WHEN se.evidence_category = 'WEAK' THEN 1 ELSE 0 END) AS weak_evidence_count
    FROM classified_evidence se
    GROUP BY se.GLOBAL_INDEX
)

SELECT
    pb.GLOBAL_INDEX,
    pb.gender,
    pb.birth_date,
    pcs.first_cad_date,
    pcs.total_score,
    pcs.evidence_types,
    pcs.gold_evidence_count,
    pcs.strong_evidence_count,
    pcs.moderate_evidence_count,
    pcs.weak_evidence_count
FROM patient_base pb
LEFT JOIN patient_cad_summary pcs
    ON pb.GLOBAL_INDEX = pcs.GLOBAL_INDEX;
