CREATE OR REPLACE VIEW cad_cta_evidence AS
SELECT DISTINCT
    img.patient_id,
    img.encounter_id,
    img.report_date,
    COALESCE(
        img.stenosis_percent,
        CASE img.stenosis_grade
            WHEN 'MODERATE' THEN 60
            WHEN 'SEVERE' THEN 80
            ELSE NULL
        END
    ) AS stenosis_percent
FROM fact_imaging_report img
WHERE img.report_type = 'CORONARY_CTA'
  AND (
      NVL(img.stenosis_percent, 0) >= 50
      OR img.stenosis_grade IN ('MODERATE', 'SEVERE')
  );
