CREATE OR REPLACE VIEW cad_long_term_antiplatelet AS
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
      FROM cad_dual_antiplatelet_therapy dapt
      WHERE dapt.patient_id = m.patient_id
        AND dapt.encounter_id = m.encounter_id
  );
