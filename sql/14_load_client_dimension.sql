USE CzechBank_DW;
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

/* Update existing current client records */
UPDATE target
SET
    target.DistrictKey = district.DistrictKey,
    target.ClientRole = source.ClientRole
FROM dbo.DimClient AS target
INNER JOIN stg.client_clean AS source
    ON target.ClientID = source.ClientID
INNER JOIN dbo.DimDistrict AS district
    ON source.DistrictID = district.DistrictID
WHERE target.IsCurrent = 1;

DECLARE @UpdatedClients INT = @@ROWCOUNT;

/* Insert clients that do not already have a current record */
INSERT INTO dbo.DimClient
(
    ClientID,
    DistrictKey,
    ClientRole,
    EffectiveFrom,
    EffectiveTo,
    IsCurrent
)
SELECT
    source.ClientID,
    district.DistrictKey,
    source.ClientRole,
    CAST(source.ETL_LoadDateTime AS DATE),
    CAST('9999-12-31' AS DATE),
    1
FROM stg.client_clean AS source
INNER JOIN dbo.DimDistrict AS district
    ON source.DistrictID = district.DistrictID
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DimClient AS target
    WHERE target.ClientID = source.ClientID
      AND target.IsCurrent = 1
);

DECLARE @InsertedClients INT = @@ROWCOUNT;

COMMIT TRANSACTION;

SELECT
    @UpdatedClients AS UpdatedClients,
    @InsertedClients AS InsertedClients;
GO

/* Validate DimClient loading */

SELECT
    COUNT(*) AS TotalClientRows,
    SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END)
        AS CurrentClientRows,
    SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END)
        AS HistoricalClientRows
FROM dbo.DimClient;
GO

SELECT COUNT(*) AS MissingClientsAfterLoad
FROM stg.client_clean AS source
LEFT JOIN dbo.DimClient AS target
    ON source.ClientID = target.ClientID
   AND target.IsCurrent = 1
WHERE target.ClientKey IS NULL;
GO

SELECT COUNT(*) AS ClientsWithInvalidDistrict
FROM dbo.DimClient AS client
LEFT JOIN dbo.DimDistrict AS district
    ON client.DistrictKey = district.DistrictKey
WHERE district.DistrictKey IS NULL;
GO

SELECT
    ClientID,
    COUNT(*) AS CurrentRecordCount
FROM dbo.DimClient
WHERE IsCurrent = 1
GROUP BY ClientID
HAVING COUNT(*) > 1;
GO

SELECT
    ClientRole,
    COUNT(*) AS ClientCount
FROM dbo.DimClient
WHERE IsCurrent = 1
GROUP BY ClientRole
ORDER BY ClientCount DESC;
GO