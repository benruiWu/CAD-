CREATE OR REPLACE VIEW cad_dual_antiplatelet_therapy AS
SELECT
    m.GLOBAL_INDEX AS GLOBAL_INDEX,
    m.encounter_id,
    MIN(m.start_date) AS therapy_start_date
FROM fact_medication m
WHERE m.medication_code IN (
    'ATC-B01AC04',
    'ATC-B01AC05',
    'ATC-B01AC24',
    'ATC-B01AC30'
)
GROUP BY m.GLOBAL_INDEX, m.encounter_id
HAVING COUNT(DISTINCT m.medication_code) >= 2;
