CREATE OR REPLACE VIEW cad_ecg_evidence AS
SELECT DISTINCT
    ecg.patient_id,
    ecg.encounter_id,
    ecg.ecg_code,
    ecg.ecg_date
FROM fact_ecg_result ecg
WHERE ecg.ecg_code IN (
    'ECG_ST_ELEVATION',
    'ECG_ST_DEPRESSION',
    'ECG_PATHOLOGIC_Q'
);
