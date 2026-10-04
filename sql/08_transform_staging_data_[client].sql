USE CzechBank_DW;
GO

/* View client and disposition relationship */
SELECT TOP 20
    c.client_id,
    c.birth_number,
    c.district_id,
    d.disp_id,
    d.account_id,
    d.type AS ClientRole
FROM stg.client AS c
LEFT JOIN stg.disp AS d
    ON c.client_id = d.client_id
ORDER BY c.client_id;
GO

/* Inspect source role categories */
SELECT
    type AS SourceClientRole,
    COUNT(*) AS NumberOfClients
FROM stg.disp
GROUP BY type
ORDER BY NumberOfClients DESC;
GO

/* Inspect roles already used by Member 2 */
SELECT
    ClientRole,
    COUNT(*) AS NumberOfClients
FROM dbo.DimClient
GROUP BY ClientRole
ORDER BY NumberOfClients DESC;
GO

/* Check clients that do not have a disposition record */
SELECT
    COUNT(*) AS ClientsWithoutDisposition
FROM stg.client AS c
LEFT JOIN stg.disp AS d
    ON c.client_id = d.client_id
WHERE d.client_id IS NULL;
GO

/* Check invalid district references */
SELECT
    COUNT(*) AS ClientsWithoutValidDistrict
FROM stg.client AS c
LEFT JOIN stg.district_clean AS d
    ON c.district_id = d.DistrictID
WHERE d.DistrictID IS NULL;
GO

/* =========================================================
   Transform client and disposition data
   ========================================================= */

DROP TABLE IF EXISTS stg.client_clean;
GO

WITH ClientSource AS
(
    SELECT
        c.client_id,
        c.district_id,
        c.birth_number,
        d.disp_id,
        d.account_id,
        d.type,
        c.ETL_LoadDateTime,

        ROW_NUMBER() OVER
        (
            PARTITION BY c.client_id
            ORDER BY
                CASE
                    WHEN UPPER(LTRIM(RTRIM(d.type))) = 'OWNER'
                    THEN 1
                    ELSE 2
                END,
                d.disp_id
        ) AS DuplicateRowNumber

    FROM stg.client AS c

    LEFT JOIN stg.disp AS d
        ON c.client_id = d.client_id
)

SELECT
    client_id AS ClientID,

    -- Invalid or missing districts are assigned to unknown
    CASE
        WHEN district_id IS NULL THEN -1
        WHEN NOT EXISTS
        (
            SELECT 1
            FROM stg.district_clean AS district
            WHERE district.DistrictID = ClientSource.district_id
        )
        THEN -1
        ELSE district_id
    END AS DistrictID,

    -- Standardize Czech banking role values
    CASE UPPER(LTRIM(RTRIM(type)))
        WHEN 'OWNER' THEN 'Owner'
        WHEN 'DISPONENT' THEN 'Authorized User'
        ELSE 'Unknown'
    END AS ClientRole,

    -- Retained for source traceability
    disp_id AS DispositionID,
    account_id AS AccountID,
    birth_number AS BirthDate,

    -- Derived demographic attribute
    DATEDIFF(YEAR, birth_number, '1999-12-31') AS AgeAtDatasetEnd,

    ETL_LoadDateTime

INTO stg.client_clean
FROM ClientSource
WHERE DuplicateRowNumber = 1
  AND client_id IS NOT NULL;
GO

/* Compare row counts */
SELECT 'Original Clients' AS DataStage, COUNT(*) AS NumberOfRows
FROM stg.client

UNION ALL

SELECT 'Transformed Clients', COUNT(*)
FROM stg.client_clean;
GO

/* Display transformed clients */
SELECT TOP 20 *
FROM stg.client_clean
ORDER BY ClientID;
GO

/* Verify standardized roles */
SELECT
    ClientRole,
    COUNT(*) AS NumberOfClients
FROM stg.client_clean
GROUP BY ClientRole
ORDER BY NumberOfClients DESC;
GO

/* Verify duplicates were removed */
SELECT
    ClientID,
    COUNT(*) AS DuplicateCount
FROM stg.client_clean
GROUP BY ClientID
HAVING COUNT(*) > 1;
GO

/* Validate district references */
SELECT COUNT(*) AS InvalidDistrictReferences
FROM stg.client_clean AS client
LEFT JOIN stg.district_clean AS district
    ON client.DistrictID = district.DistrictID
WHERE district.DistrictID IS NULL
  AND client.DistrictID <> -1;
GO