USE CzechBank_DW;
GO

SET NOCOUNT ON;
GO

/*==============================================================
  1. Remove DimDistrict if it already exists

  Run this before creating DimClient and fact foreign keys.
==============================================================*/

IF OBJECT_ID('dbo.DimDistrict', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.DimDistrict;
END;
GO

/*==============================================================
  2. Create DimDistrict
==============================================================*/

CREATE TABLE dbo.DimDistrict
(
    DistrictKey          INT IDENTITY(1,1) NOT NULL,
    DistrictID           INT               NOT NULL,
    DistrictName         NVARCHAR(100)     NOT NULL,
    RegionName           NVARCHAR(100)     NOT NULL,
    Population           INT               NULL,
    AverageSalary        INT               NULL,
    UnemploymentMeasure  DECIMAL(5,2)      NULL,
    EntrepreneurMeasure  INT               NULL,
    CrimeMeasure         INT               NULL,

    CONSTRAINT PK_DimDistrict
        PRIMARY KEY (DistrictKey),

    CONSTRAINT UQ_DimDistrict_DistrictID
        UNIQUE (DistrictID),

    CONSTRAINT CK_DimDistrict_Population
        CHECK
        (
            Population IS NULL
            OR Population >= 0
        ),

    CONSTRAINT CK_DimDistrict_AverageSalary
        CHECK
        (
            AverageSalary IS NULL
            OR AverageSalary >= 0
        ),

    CONSTRAINT CK_DimDistrict_Unemployment
        CHECK
        (
            UnemploymentMeasure IS NULL
            OR UnemploymentMeasure >= 0
        ),

    CONSTRAINT CK_DimDistrict_Entrepreneurs
        CHECK
        (
            EntrepreneurMeasure IS NULL
            OR EntrepreneurMeasure >= 0
        ),

    CONSTRAINT CK_DimDistrict_Crime
        CHECK
        (
            CrimeMeasure IS NULL
            OR CrimeMeasure >= 0
        )
);
GO

/*==============================================================
  3. Create lookup index
==============================================================*/

CREATE INDEX IX_DimDistrict_DistrictID
ON dbo.DimDistrict
(
    DistrictID
);
GO

/*==============================================================
  4. Insert Unknown District member

  DistrictKey 0 is used when a Client or Account cannot be
  matched to a source District.
==============================================================*/

SET IDENTITY_INSERT dbo.DimDistrict ON;
GO

INSERT INTO dbo.DimDistrict
(
    DistrictKey,
    DistrictID,
    DistrictName,
    RegionName,
    Population,
    AverageSalary,
    UnemploymentMeasure,
    EntrepreneurMeasure,
    CrimeMeasure
)
VALUES
(
    0,
    -1,
    N'Unknown',
    N'Unknown',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);
GO

SET IDENTITY_INSERT dbo.DimDistrict OFF;
GO

/*==============================================================
  5. Load District data

  Source table:
      CzechBank_DW.dbo.district

  This assumes district has the improved English column names:
      district_id
      district_name
      region_name
      population
      average_salary
      unemployment_rate_1995
      unemployment_rate_1996
      entrepreneurs_per_1000_residents
      crimes_committed_1995
      crimes_committed_1996

  UnemploymentMeasure:
      Uses 1996 rate, with 1995 as fallback.

  CrimeMeasure:
      Uses 1996 crime count, with 1995 as fallback.
==============================================================*/

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
    TRY_CONVERT
    (
        INT,
        d.district_id
    ) AS DistrictID,

    COALESCE
    (
        NULLIF
        (
            LTRIM(RTRIM(d.district_name)),
            N''
        ),
        N'Unknown'
    ) AS DistrictName,

    COALESCE
    (
        NULLIF
        (
            LTRIM(RTRIM(d.region_name)),
            N''
        ),
        N'Unknown'
    ) AS RegionName,

    TRY_CONVERT
    (
        INT,
        d.population
    ) AS Population,

    TRY_CONVERT
    (
        INT,
        d.average_salary
    ) AS AverageSalary,

    COALESCE
    (
        TRY_CONVERT
        (
            DECIMAL(5,2),
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CONVERT
                        (
                            NVARCHAR(50),
                            d.unemployment_rate_1996
                        )
                    )
                ),
                N''
            )
        ),

        TRY_CONVERT
        (
            DECIMAL(5,2),
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CONVERT
                        (
                            NVARCHAR(50),
                            d.unemployment_rate_1995
                        )
                    )
                ),
                N''
            )
        )
    ) AS UnemploymentMeasure,

    TRY_CONVERT
    (
        INT,
        NULLIF
        (
            LTRIM
            (
                RTRIM
                (
                    CONVERT
                    (
                        NVARCHAR(50),
                        d.entrepreneurs_per_1000_residents
                    )
                )
            ),
            N''
        )
    ) AS EntrepreneurMeasure,

    COALESCE
    (
        TRY_CONVERT
        (
            INT,
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CONVERT
                        (
                            NVARCHAR(50),
                            d.crimes_committed_1996
                        )
                    )
                ),
                N''
            )
        ),

        TRY_CONVERT
        (
            INT,
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CONVERT
                        (
                            NVARCHAR(50),
                            d.crimes_committed_1995
                        )
                    )
                ),
                N''
            )
        )
    ) AS CrimeMeasure

FROM CzechBank_DW.dbo.district AS d

WHERE TRY_CONVERT(INT, d.district_id) IS NOT NULL

AND NOT EXISTS
(
    SELECT 1
    FROM dbo.DimDistrict AS existing
    WHERE existing.DistrictID =
          TRY_CONVERT(INT, d.district_id)
);
GO

/*==============================================================
  6. Validate the loaded dimension
==============================================================*/

SELECT
    COUNT(*) AS TotalDimDistrictRows,

    COUNT
    (
        DISTINCT
        CASE
            WHEN DistrictID <> -1
            THEN DistrictID
        END
    ) AS DistinctSourceDistricts,

    MIN
    (
        CASE
            WHEN DistrictID <> -1
            THEN Population
        END
    ) AS MinimumPopulation,

    MAX
    (
        CASE
            WHEN DistrictID <> -1
            THEN Population
        END
    ) AS MaximumPopulation,

    AVG
    (
        CONVERT
        (
            DECIMAL(18,2),
            AverageSalary
        )
    ) AS OverallAverageSalary

FROM dbo.DimDistrict;
GO

/*==============================================================
  7. Display loaded District records
==============================================================*/

SELECT
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

ORDER BY DistrictKey;
GO

/*==============================================================
  8. Check NULL measure values
==============================================================*/

SELECT
    SUM
    (
        CASE
            WHEN Population IS NULL THEN 1
            ELSE 0
        END
    ) AS MissingPopulation,

    SUM
    (
        CASE
            WHEN AverageSalary IS NULL THEN 1
            ELSE 0
        END
    ) AS MissingAverageSalary,

    SUM
    (
        CASE
            WHEN UnemploymentMeasure IS NULL THEN 1
            ELSE 0
        END
    ) AS MissingUnemployment,

    SUM
    (
        CASE
            WHEN EntrepreneurMeasure IS NULL THEN 1
            ELSE 0
        END
    ) AS MissingEntrepreneurMeasure,

    SUM
    (
        CASE
            WHEN CrimeMeasure IS NULL THEN 1
            ELSE 0
        END
    ) AS MissingCrimeMeasure

FROM dbo.DimDistrict

WHERE DistrictID <> -1;
GO

/*==============================================================
  9. Find duplicated source District IDs
==============================================================*/

SELECT
    district_id,
    COUNT(*) AS DuplicateCount

FROM CzechBank_DW.dbo.district

GROUP BY district_id

HAVING COUNT(*) > 1;
GO