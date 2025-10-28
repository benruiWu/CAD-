CREATE OR REPLACE VIEW cad_chronic_condition_history AS
SELECT DISTINCT
    c.GLOBAL_INDEX AS GLOBAL_INDEX,
    c.condition_code,
    c.record_date
FROM fact_chronic_condition c
WHERE c.condition_code IN (
    'HYPERTENSION',
    'DIABETES',
    'HYPERLIPIDEMIA'
);
