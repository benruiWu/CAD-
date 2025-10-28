CREATE OR REPLACE VIEW cad_procedure_evidence AS
SELECT DISTINCT
    op.patient_id,
    op.encounter_id,
    op.procedure_code,
    op.procedure_date
FROM fact_procedure op
WHERE op.procedure_code IN (
    'PCI',
    '0210093',
    '0211093'
);
