CREATE OR REPLACE VIEW cad_maintenance_medications AS
SELECT DISTINCT
    m.patient_id,
    m.encounter_id,
    m.medication_code,
    m.start_date
FROM fact_medication m
WHERE m.medication_code IN (
    'ATC-C01DA02',
    'ATC-C10AA05'
);
