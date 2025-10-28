CREATE OR REPLACE VIEW cad_general_symptom_evidence AS
SELECT DISTINCT
    s.GLOBAL_INDEX AS GLOBAL_INDEX,
    s.encounter_id,
    s.symptom_code,
    s.symptom_date
FROM fact_encounter_symptom s
WHERE s.symptom_code IN (
    'CHEST_TIGHTNESS',
    'DYSPNEA',
    'EPIGASTRIC_DISCOMFORT',
    'FATIGUE'
);
