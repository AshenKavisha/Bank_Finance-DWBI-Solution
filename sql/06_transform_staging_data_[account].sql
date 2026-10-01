use CzechBank_DW;
Go
/* =========================================================
   STEP 1: Inspect account source values before transformation
   ========================================================= */
SELECT TOP 20
    account_id,
    district_id,
    frequency,
    date AS AccountOpenDate,
    ETL_LoadDateTime
FROM stg.account
ORDER BY account_id;
GO

-- View source account records
SELECT TOP 20
    account_id,
    district_id,
    frequency,
    date AS AccountOpenDate,
    ETL_LoadDateTime
FROM stg.account
ORDER BY account_id;
GO

-- Identify the different statement-frequency values
SELECT
    frequency,
    COUNT(*) AS NumberOfAccounts
FROM stg.account
GROUP BY frequency
ORDER BY NumberOfAccounts DESC;
GO

-- Check the existing warehouse transformation results
SELECT
    StatementFrequency,
    AccountAgeGroup,
    COUNT(*) AS NumberOfAccounts
FROM dbo.DimAccount
GROUP BY StatementFrequency, AccountAgeGroup
ORDER BY StatementFrequency, AccountAgeGroup;
GO

/* =========================================================
   STEP 2: Clean and transform account staging data
   ========================================================= */

DROP TABLE IF EXISTS stg.account_clean;
GO

WITH DeduplicatedAccounts AS
(
    SELECT
        account_id,
        district_id,
        frequency,
        date,
        ETL_LoadDateTime,

        ROW_NUMBER() OVER
        (
            PARTITION BY account_id
            ORDER BY ETL_LoadDateTime DESC
        ) AS DuplicateRowNumber

    FROM stg.account
)

SELECT
    account_id AS AccountID,

    -- Replace a missing district with the unknown identifier
    COALESCE(district_id, -1) AS DistrictID,

    -- Remove extra spaces and translate Czech values
    CASE UPPER(LTRIM(RTRIM(frequency)))
        WHEN 'POPLATEK MESICNE' THEN 'Monthly'
        WHEN 'POPLATEK TYDNE' THEN 'Weekly'
        WHEN 'POPLATEK PO OBRATU' THEN 'After Transaction'
        ELSE 'Unknown'
    END AS StatementFrequency,

    -- Retain the proper SQL date
    date AS AccountOpenDate,

    -- Convert the date into a warehouse date key: YYYYMMDD
    CASE
        WHEN date IS NOT NULL
        THEN CONVERT(INT, CONVERT(CHAR(8), date, 112))
        ELSE 19000101
    END AS AccountOpenDateKey,

    -- Dataset observation period ends in 1999
    DATEDIFF(YEAR, date, '1999-12-31') AS AccountAgeYears,

    -- Derive the age category used by the warehouse
    CASE
        WHEN date IS NULL THEN 'Unknown'
        WHEN DATEDIFF(YEAR, date, '1999-12-31') BETWEEN 1 AND 4
            THEN '1-4 Years'
        WHEN DATEDIFF(YEAR, date, '1999-12-31') BETWEEN 5 AND 9
            THEN '5-9 Years'
        ELSE 'Other'
    END AS AccountAgeGroup,

    'Czech Bank Dataset' AS SourceSystem,
    ETL_LoadDateTime

INTO stg.account_clean
FROM DeduplicatedAccounts

-- Remove duplicate IDs and reject records without an account ID
WHERE DuplicateRowNumber = 1
  AND account_id IS NOT NULL;
GO

/* =========================================================
   STEP 3: compare Original and transforemd data
   ========================================================= */


/* Compare original and transformed row counts */
SELECT 'Original' AS DataStage, COUNT(*) AS NumberOfRows
FROM stg.account

UNION ALL

SELECT 'Transformed', COUNT(*)
FROM stg.account_clean;
GO

/* View transformed records */
SELECT TOP 20 *
FROM stg.account_clean
ORDER BY AccountID;
GO

/* Confirm standardized values and derived groups */
SELECT
    StatementFrequency,
    AccountAgeGroup,
    COUNT(*) AS NumberOfAccounts
FROM stg.account_clean
GROUP BY StatementFrequency, AccountAgeGroup
ORDER BY StatementFrequency, AccountAgeGroup;
GO

/* Confirm that duplicate IDs were removed */
SELECT
    AccountID,
    COUNT(*) AS DuplicateCount
FROM stg.account_clean
GROUP BY AccountID
HAVING COUNT(*) > 1;
GO



