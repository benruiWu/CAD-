CREATE OR REPLACE VIEW cad_tnc_test AS
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
   OR EX_PROJ_NAME LIKE '%Troponin%';

CREATE OR REPLACE VIEW cad_tnc_positive_results AS
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
FROM cad_tnc_test t;

CREATE OR REPLACE VIEW cad_lab_biomarker_evidence AS
SELECT DISTINCT
    t.PATIENT_ID AS patient_id,
    t.VISIT_ID AS encounter_id,
    t.EX_PROJ_NAME AS test_code,
    t.REPORT_TIME AS test_date,
    NVL(t.numeric_result, t.UNL) AS result_value
FROM cad_tnc_positive_results t
WHERE t.positive_flag = 1;
