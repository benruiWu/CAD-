CREATE OR REPLACE VIEW cad_maintenance_medications AS
SELECT DISTINCT
    m.GLOBAL_INDEX AS GLOBAL_INDEX,
    m.encounter_id,
    m.medication_code,
    m.start_date
FROM fact_medication m
WHERE m.medication_code IN (
    'ATC-C01DA02',
    'ATC-C10AA05'
);
