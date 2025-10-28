CREATE OR REPLACE VIEW cad_angiography_evidence AS
SELECT DISTINCT
    img.patient_id,
    img.encounter_id,
    img.report_date,
    img.stenosis_percent
FROM fact_imaging_report img
WHERE img.report_type = 'CORONARY_ANGIOGRAPHY'
  AND NVL(img.stenosis_percent, 0) > 50;
