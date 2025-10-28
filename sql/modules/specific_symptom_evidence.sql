CREATE OR REPLACE VIEW cad_specific_symptom_evidence AS
SELECT DISTINCT
    s.patient_id,
    s.encounter_id,
    s.symptom_code,
    s.symptom_date
FROM fact_encounter_symptom s
WHERE s.symptom_code IN (
    'TYPICAL_ANGINA',
    'REST_CHEST_PAIN',
    'ANGINA_EQUIVALENT',
    'CHEST_PAIN_RADIATING',
    'CHEST_PAIN_WITH_DIAPHORESIS'
);
