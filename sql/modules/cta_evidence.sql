CREATE OR REPLACE VIEW cad_cta_evidence AS
WITH cta_raw AS (
    SELECT
        ROW_ID,
        RESULT_ID,
        CHK_DT,
        GLOBAL_INDEX,
        CHECK_H_PROJ_NAME,
        RPT_DESCRIP,
        PRT_SEEING
    FROM KSRAWDATA_2024_08.Z01_HOS_EXAMINATIONDETAILS
    WHERE (
            CHECK_H_PROJ_NAME LIKE '%冠%'
        AND CHECK_H_PROJ_NAME LIKE '%脉%'
        AND (
            CHECK_H_PROJ_NAME LIKE '%CT%'
            OR CHECK_H_PROJ_NAME LIKE '%造影%'
        )
    )
),
cad_judgment_base AS (
    SELECT
        r.ROW_ID,
        r.RESULT_ID,
        r.CHK_DT,
        r.GLOBAL_INDEX,
        r.CHECK_H_PROJ_NAME,
        r.RPT_DESCRIP,
        r.PRT_SEEING,
        CASE
            WHEN UPPER(r.PRT_SEEING) LIKE '%支架%'
                OR UPPER(r.PRT_SEEING) LIKE '%PCI%'
                OR UPPER(r.PRT_SEEING) LIKE '%手术%'
                OR UPPER(r.PRT_SEEING) LIKE '%术后%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS2V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS2S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 2V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 2S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-2V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-2S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS1V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS1S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 1V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 1S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-1V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-1S%'
            THEN 1
            WHEN UPPER(r.PRT_SEEING) LIKE '%中度狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度+狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%重度狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%重度变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%重变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%重狭窄%'
            THEN 1
            WHEN UPPER(r.PRT_SEEING) LIKE '%冠脉%不同程度%窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%冠状%不同程度%窄%'
            THEN 1
            WHEN UPPER(r.PRT_SEEING) LIKE '%50\%%' ESCAPE '\'
                AND UPPER(r.PRT_SEEING) LIKE '%窄%'
            THEN 1
            WHEN UPPER(r.PRT_SEEING) LIKE '冠状动脉粥样硬化。'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS 3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS-3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS 4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS-4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS 3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS-3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS 4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS-4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS 5%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS 5%'
            THEN 1
            WHEN UPPER(r.PRT_SEEING) LIKE '%斑块%'
                AND (
                    UPPER(r.PRT_SEEING) LIKE '%中度狭窄%'
                    OR UPPER(r.PRT_SEEING) LIKE '%重度狭窄%'
                )
            THEN 1
            ELSE 0
        END AS IS_CAD,
        CASE
            WHEN UPPER(r.PRT_SEEING) LIKE '%支架%'
                OR UPPER(r.PRT_SEEING) LIKE '%PCI%'
                OR UPPER(r.PRT_SEEING) LIKE '%手术%'
                OR UPPER(r.PRT_SEEING) LIKE '%术后%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS2V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS2S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 2V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 2S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-2V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-2S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS1V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS1S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 1V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS 1S%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-1V%'
                OR UPPER(r.PRT_SEEING) LIKE '%RADS-1S%'
            THEN '支架植入史'
            WHEN (
                UPPER(r.PRT_SEEING) LIKE '%中度狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度+狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中变窄%'
            )
            AND r.PRT_SEEING NOT LIKE '%轻中%'
            AND r.PRT_SEEING NOT LIKE '%轻-中%'
            AND r.PRT_SEEING NOT LIKE '%轻、中%'
            THEN '中度管腔狭窄'
            WHEN (
                UPPER(r.PRT_SEEING) LIKE '%中度狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度+狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%中变窄%'
            )
            AND (
                r.PRT_SEEING LIKE '%轻中%'
                OR r.PRT_SEEING LIKE '%轻-中%'
                OR r.PRT_SEEING LIKE '%轻、中%'
            )
            THEN '轻、中度管腔狭窄'
            WHEN UPPER(r.PRT_SEEING) LIKE '%重度狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%重度变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%重变窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%重狭窄%'
            THEN '重度管腔狭窄'
            WHEN UPPER(r.PRT_SEEING) LIKE '%冠脉%不同程度%窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%冠状%不同程度%窄%'
            THEN '冠脉不同程度狭窄'
            WHEN UPPER(r.PRT_SEEING) LIKE '%斑块%'
                AND UPPER(r.PRT_SEEING) LIKE '%中度狭窄%'
            THEN '斑块伴中度狭窄'
            WHEN UPPER(r.PRT_SEEING) LIKE '%斑块%'
                AND UPPER(r.PRT_SEEING) LIKE '%重度狭窄%'
            THEN '斑块伴重度狭窄'
            WHEN UPPER(r.PRT_SEEING) LIKE '%50\%%' ESCAPE '\'
                AND UPPER(r.PRT_SEEING) LIKE '%窄%'
            THEN '狭窄超50%'
            WHEN UPPER(r.PRT_SEEING) LIKE '冠状动脉粥样硬化。'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS 3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS-3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS 4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS-4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS 3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS-3%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS 4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS-4%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD-RADS 5%'
                OR UPPER(r.PRT_SEEING) LIKE '%CAD RADS 5%'
            THEN '明确动脉粥样硬化'
            ELSE NULL
        END AS CAD_REASON,
        CASE
            WHEN UPPER(r.PRT_SEEING) LIKE '%支架%'
                OR UPPER(r.PRT_SEEING) LIKE '%PCI%'
                OR UPPER(r.PRT_SEEING) LIKE '%手术%'
                OR UPPER(r.PRT_SEEING) LIKE '%术后%'
            THEN 0
            WHEN UPPER(r.PRT_SEEING) LIKE '%重度%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度%'
            THEN 0
            WHEN UPPER(r.PRT_SEEING) LIKE '%未见明显狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见明确狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见异常%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见明确异常%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见斑块及明显狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见斑块及狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见明显斑块及狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见明显异常%'
            THEN 1
            WHEN (
                UPPER(r.PRT_SEEING) LIKE '%心肌桥%'
                OR UPPER(r.PRT_SEEING) LIKE '%与心肌关系%'
            )
            AND UPPER(r.PRT_SEEING) NOT LIKE '%斑块%'
            AND UPPER(r.PRT_SEEING) NOT LIKE '%狭窄%'
            AND UPPER(r.PRT_SEEING) NOT LIKE '%变窄%'
            AND UPPER(r.PRT_SEEING) NOT LIKE '%动脉粥样硬化%'
            THEN 1
            WHEN UPPER(r.PRT_SEEING) LIKE '%轻%'
                AND (
                    UPPER(r.PRT_SEEING) LIKE '%狭窄%'
                    OR UPPER(r.PRT_SEEING) LIKE '%变窄%'
                )
                AND UPPER(r.PRT_SEEING) NOT LIKE '%中度%'
                AND UPPER(r.PRT_SEEING) NOT LIKE '%重度%'
            THEN 1
            WHEN UPPER(r.PRT_SEEING) LIKE '%少许斑块%'
                AND UPPER(r.PRT_SEEING) NOT LIKE '%狭窄%'
            THEN 1
            ELSE 0
        END AS IS_NON_CAD,
        CASE
            WHEN UPPER(r.PRT_SEEING) LIKE '%支架%'
                OR UPPER(r.PRT_SEEING) LIKE '%PCI%'
                OR UPPER(r.PRT_SEEING) LIKE '%手术%'
                OR UPPER(r.PRT_SEEING) LIKE '%术后%'
            THEN NULL
            WHEN UPPER(r.PRT_SEEING) LIKE '%重度%'
                OR UPPER(r.PRT_SEEING) LIKE '%中度%'
            THEN NULL
            WHEN UPPER(r.PRT_SEEING) LIKE '%未见明显狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见异常%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见明确异常%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见斑块及明显狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见斑块及狭窄%'
                OR UPPER(r.PRT_SEEING) LIKE '%未见明显斑块及狭窄%'
            THEN '报告明确无狭窄'
            WHEN (
                UPPER(r.PRT_SEEING) LIKE '%心肌桥%'
                OR UPPER(r.PRT_SEEING) LIKE '%与心肌关系%'
            )
            AND UPPER(r.PRT_SEEING) NOT LIKE '%斑块%'
            AND UPPER(r.PRT_SEEING) NOT LIKE '%狭窄%'
            AND UPPER(r.PRT_SEEING) NOT LIKE '%变窄%'
            AND UPPER(r.PRT_SEEING) NOT LIKE '%动脉粥样硬化%'
            THEN '仅有心肌桥，无斑块狭窄'
            WHEN UPPER(r.PRT_SEEING) LIKE '%轻%'
                AND UPPER(r.PRT_SEEING) LIKE '%狭窄%'
                AND UPPER(r.PRT_SEEING) NOT LIKE '%中度%'
                AND UPPER(r.PRT_SEEING) NOT LIKE '%重度%'
            THEN '仅有轻度狭窄，不诊断为CAD'
            WHEN UPPER(r.PRT_SEEING) LIKE '%少许斑块%'
                AND UPPER(r.PRT_SEEING) NOT LIKE '%狭窄%'
            THEN '仅有轻微斑块，无管腔狭窄'
            ELSE NULL
        END AS NON_CAD_REASON
    FROM cta_raw r
),
cad_cad_judgment AS (
    SELECT
        b.ROW_ID,
        b.RESULT_ID,
        b.GLOBAL_INDEX,
        b.CHK_DT,
        b.CHECK_H_PROJ_NAME,
        b.RPT_DESCRIP,
        b.PRT_SEEING,
        b.IS_CAD,
        b.CAD_REASON,
        b.IS_NON_CAD,
        b.NON_CAD_REASON,
        CASE
            WHEN b.IS_CAD = 1 AND b.IS_NON_CAD = 1 THEN '矛盾，需人工判断'
            WHEN b.IS_CAD = 1 THEN 'CAD'
            WHEN b.IS_NON_CAD = 1 THEN '非CAD'
            ELSE '需人工判断'
        END AS FINAL_JUDGMENT,
        CASE
            WHEN b.IS_CAD = 1 AND b.IS_NON_CAD = 1 THEN '同时满足CAD条件(' || b.CAD_REASON || ')和非CAD条件(' || b.NON_CAD_REASON || ')，存在矛盾'
            WHEN b.IS_CAD = 1 THEN b.CAD_REASON
            WHEN b.IS_NON_CAD = 1 THEN b.NON_CAD_REASON
            ELSE '未满足明确的CAD或非CAD判断标准'
        END AS FINAL_REASON
    FROM cad_judgment_base b
),
cad_cad_judgment_final AS (
    SELECT
        j.ROW_ID,
        j.RESULT_ID,
        j.GLOBAL_INDEX,
        j.CHK_DT,
        j.CHECK_H_PROJ_NAME,
        j.RPT_DESCRIP,
        j.PRT_SEEING,
        j.IS_CAD,
        j.CAD_REASON,
        j.IS_NON_CAD,
        j.NON_CAD_REASON,
        j.FINAL_JUDGMENT,
        j.FINAL_REASON,
        CASE
            WHEN j.IS_CAD = 1 THEN 1
            WHEN j.IS_NON_CAD = 1 AND j.IS_CAD = 0 THEN 0
            WHEN j.IS_NON_CAD = 0
                AND j.IS_CAD = 0
                AND (
                    j.PRT_SEEING LIKE '%重新%'
                    OR j.PRT_SEEING LIKE '%重做%'
                    OR j.PRT_SEEING LIKE '%退费%'
                    OR j.PRT_SEEING LIKE '%配合差%'
                    OR j.PRT_SEEING IS NULL
                    OR j.PRT_SEEING LIKE '1'
                    OR j.PRT_SEEING LIKE '%错层%'
                    OR j.PRT_SEEING LIKE ''
                    OR j.PRT_SEEING LIKE '%显示不清%'
                    OR j.PRT_SEEING LIKE 'CT室'
                    OR j.PRT_SEEING LIKE '归档%'
                )
            THEN NULL
            ELSE 0
        END AS IS_CAD_FINAL
    FROM cad_cad_judgment j
)
SELECT
    f.GLOBAL_INDEX,
    f.RESULT_ID AS encounter_id,
    f.CHK_DT AS report_date,
    CAST(NULL AS NUMBER) AS stenosis_percent,
    f.CAD_REASON,
    f.FINAL_REASON
FROM cad_cad_judgment_final f
WHERE f.IS_CAD_FINAL = 1;
