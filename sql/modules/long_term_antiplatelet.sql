-- 长期抗板药物使用识别
CREATE TABLE CAD_LONGTERM_ANTIPLATELET_DRUG AS
WITH month_use AS (
    -- 1️⃣ 提取每人每月用药（去重）
    SELECT DISTINCT
        GLOBAL_INDEX,
        TRUNC(DRUG_DATE, 'MM') AS DRUG_MONTH_START
    FROM
        KSQC_2024.SQC_WM_PRESCRIPTIONS_ALL
    WHERE
        CAT_CODE = 'XB01AC'
),
grp AS (
    -- 2️⃣ 识别连续月份段
    SELECT
        GLOBAL_INDEX,
        DRUG_MONTH_START,
        ADD_MONTHS(
            DRUG_MONTH_START,
            -ROW_NUMBER() OVER (PARTITION BY GLOBAL_INDEX ORDER BY DRUG_MONTH_START)
        ) AS grp_id
    FROM
        month_use
),
continuous AS (
    -- 3️⃣ 聚合得到连续段起止月份
    SELECT
        GLOBAL_INDEX,
        MIN(DRUG_MONTH_START) AS START_MONTH,
        MAX(DRUG_MONTH_START) AS END_MONTH,
        COUNT(*) AS CONSECUTIVE_MONTHS
    FROM
        grp
    GROUP BY
        GLOBAL_INDEX,
        grp_id
),
continuous_with_start AS (
    -- 4️⃣ 连接原始表以获取该段内最早处方日期
    SELECT
        c.GLOBAL_INDEX,
        c.START_MONTH,
        c.END_MONTH,
        c.CONSECUTIVE_MONTHS,
        MIN(p.DRUG_DATE) AS FIRST_DRUG_DATE
    FROM
        continuous c
        JOIN KSQC_2024.SQC_WM_PRESCRIPTIONS_ALL p
            ON p.GLOBAL_INDEX = c.GLOBAL_INDEX
           AND p.CAT_CODE = 'XB01AC'
           AND TRUNC(p.DRUG_DATE, 'MM') BETWEEN c.START_MONTH AND c.END_MONTH
    GROUP BY
        c.GLOBAL_INDEX,
        c.START_MONTH,
        c.END_MONTH,
        c.CONSECUTIVE_MONTHS
)
-- 5️⃣ 输出连续 ≥6 个月的患者及真实开始日期
SELECT
    GLOBAL_INDEX,
    START_MONTH,
    END_MONTH,
    FIRST_DRUG_DATE AS REAL_START_DATE,
    CONSECUTIVE_MONTHS
FROM
    continuous_with_start
WHERE
    CONSECUTIVE_MONTHS >= 6
ORDER BY
    GLOBAL_INDEX,
    START_MONTH;

-- 提供长期抗板证据信息的视图
CREATE OR REPLACE VIEW cad_long_term_antiplatelet AS
SELECT
    d.GLOBAL_INDEX,
    CAST(NULL AS VARCHAR2(64)) AS encounter_id,
    d.REAL_START_DATE AS therapy_start_date,
    d.CONSECUTIVE_MONTHS AS therapy_months,
    d.START_MONTH,
    d.END_MONTH
FROM
    CAD_LONGTERM_ANTIPLATELET_DRUG d;
