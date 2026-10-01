USE CzechBank_DW;
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

-- Update existing districts with the latest cleaned values
UPDATE target
SET
    target.DistrictName = source.DistrictName,
    target.RegionName = source.RegionName,
    target.Population = source.Population,
    target.AverageSalary = source.AverageSalary,
    target.UnemploymentMeasure = source.UnemploymentMeasure,
    target.EntrepreneurMeasure = source.EntrepreneurMeasure,
    target.CrimeMeasure = source.CrimeMeasure
FROM dbo.DimDistrict AS target
INNER JOIN stg.district_clean AS source
    ON target.DistrictID = source.DistrictID
WHERE target.DistrictID <> -1;

DECLARE @UpdatedDistricts INT = @@ROWCOUNT;

-- Insert only districts that are not already in the dimension
INSERT INTO dbo.DimDistrict
(
    DistrictID,
    DistrictName,
    RegionName,
    Population,
    AverageSalary,
    UnemploymentMeasure,
    EntrepreneurMeasure,
    CrimeMeasure
)
SELECT
    source.DistrictID,
    source.DistrictName,
    source.RegionName,
    source.Population,
    source.AverageSalary,
    source.UnemploymentMeasure,
    source.EntrepreneurMeasure,
    source.CrimeMeasure
FROM stg.district_clean AS source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DimDistrict AS target
    WHERE target.DistrictID = source.DistrictID
);

DECLARE @InsertedDistricts INT = @@ROWCOUNT;

COMMIT TRANSACTION;

-- Display loading results
SELECT
    @UpdatedDistricts AS UpdatedDistricts,
    @InsertedDistricts AS InsertedDistricts;
GO

/* Validate DimDistrict loading */

SELECT
    COUNT(*) AS TotalDistrictRows,
    SUM(CASE WHEN DistrictID = -1 THEN 1 ELSE 0 END)
        AS UnknownRows,
    SUM(CASE WHEN DistrictID <> -1 THEN 1 ELSE 0 END)
        AS BusinessDistrictRows
FROM dbo.DimDistrict;
GO

-- Confirm every cleaned district exists in DimDistrict
SELECT COUNT(*) AS MissingDistrictsAfterLoad
FROM stg.district_clean AS source
LEFT JOIN dbo.DimDistrict AS target
    ON source.DistrictID = target.DistrictID
WHERE target.DistrictKey IS NULL;
GO

SELECT TOP 10
    DistrictKey,
    DistrictID,
    DistrictName,
    RegionName,
    Population,
    AverageSalary,
    UnemploymentMeasure,
    EntrepreneurMeasure,
    CrimeMeasure
FROM dbo.DimDistrict
ORDER BY DistrictID;
GO