/* =========================================================
   STEP 4: Inspect district source data
   ========================================================= */

-- Display the complete district column names
SELECT
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'district'
ORDER BY ORDINAL_POSITION;
GO

-- View sample district data
SELECT TOP 10 *
FROM stg.district
ORDER BY district_id;
GO

-- Check missing values in the fields needed by DimDistrict
SELECT
    COUNT(*) AS TotalDistricts,
    SUM(CASE WHEN district_id IS NULL THEN 1 ELSE 0 END)
        AS MissingDistrictID,
    SUM(CASE WHEN district_name IS NULL OR LTRIM(RTRIM(district_name)) = ''
             THEN 1 ELSE 0 END)
        AS MissingDistrictName,
    SUM(CASE WHEN region_name IS NULL OR LTRIM(RTRIM(region_name)) = ''
             THEN 1 ELSE 0 END)
        AS MissingRegionName,
    SUM(CASE WHEN population IS NULL THEN 1 ELSE 0 END)
        AS MissingPopulation,
    SUM(CASE WHEN average_salary IS NULL THEN 1 ELSE 0 END)
        AS MissingAverageSalary
FROM stg.district;
GO

-- Check for duplicate district identifiers
SELECT
    district_id,
    COUNT(*) AS DuplicateCount
FROM stg.district
GROUP BY district_id
HAVING COUNT(*) > 1;
GO


USE CzechBank_DW;
GO

DROP TABLE IF EXISTS stg.district_clean;
GO

WITH DeduplicatedDistricts AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY district_id
            ORDER BY ETL_LoadDateTime DESC
        ) AS DuplicateRowNumber
    FROM stg.district
)

SELECT
    district_id AS DistrictID,

    -- Clean text by removing unwanted spaces
    COALESCE(
        NULLIF(LTRIM(RTRIM(district_name)), ''),
        'Unknown'
    ) AS DistrictName,

    COALESCE(
        NULLIF(LTRIM(RTRIM(region_name)), ''),
        'Unknown'
    ) AS RegionName,

    population AS Population,

    -- Convert FLOAT salary into the warehouse integer datatype
    CAST(ROUND(average_salary, 0) AS INT) AS AverageSalary,

    -- Use newer unemployment data, with 1995 as fallback
    CAST(
        COALESCE(
            unemployment_rate_1996,
            unemployment_rate_1995
        )
        AS DECIMAL(5,2)
    ) AS UnemploymentMeasure,

    entrepreneurs_per_1000_residents AS EntrepreneurMeasure,

    -- Use newer crime data, with 1995 as fallback
    COALESCE(
        crimes_committed_1996,
        crimes_committed_1995
    ) AS CrimeMeasure,

    ETL_LoadDateTime

INTO stg.district_clean
FROM DeduplicatedDistricts
WHERE DuplicateRowNumber = 1
  AND district_id IS NOT NULL;
GO

/* Compare row counts */
SELECT 'Original' AS DataStage, COUNT(*) AS NumberOfRows
FROM stg.district

UNION ALL

SELECT 'Transformed', COUNT(*)
FROM stg.district_clean;
GO

/* View the transformed results */
SELECT TOP 20 *
FROM stg.district_clean
ORDER BY DistrictID;
GO

/* Confirm the selected measures no longer contain missing values */
SELECT
    COUNT(*) AS TotalDistricts,
    SUM(CASE WHEN UnemploymentMeasure IS NULL THEN 1 ELSE 0 END)
        AS MissingUnemploymentMeasure,
    SUM(CASE WHEN CrimeMeasure IS NULL THEN 1 ELSE 0 END)
        AS MissingCrimeMeasure
FROM stg.district_clean;
GO

/* Confirm duplicate district IDs were removed */
SELECT
    DistrictID,
    COUNT(*) AS DuplicateCount
FROM stg.district_clean
GROUP BY DistrictID
HAVING COUNT(*) > 1;
GO