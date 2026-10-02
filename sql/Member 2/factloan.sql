USE CzechBank_DW;
GO

SET NOCOUNT ON;
GO

/*==============================================================
  1. Drop FactLoan if it already exists

  Run this before creating Power BI relationships.
==============================================================*/

IF OBJECT_ID('dbo.FactLoan', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.FactLoan;
END;
GO

/*==============================================================
  2. Create FactLoan

  Grain:
      One row represents one loan issued to one account.

  Integer fields use INT.
  Monetary fields use DECIMAL(18,2).
==============================================================*/

CREATE TABLE dbo.FactLoan
(
    LoanKey                INT IDENTITY(1,1) NOT NULL,
    LoanID                 INT               NOT NULL,
    LoanDateKey            INT               NOT NULL,
    AccountKey             INT               NOT NULL,
    DistrictKey            INT               NOT NULL,
    LoanStatusKey          INT               NOT NULL,
    LoanCount              INT               NOT NULL,
    LoanAmount             DECIMAL(18,2)     NOT NULL,
    LoanDurationMonths     INT               NOT NULL,
    MonthlyPayment         DECIMAL(18,2)     NOT NULL,
    ExpectedPaymentAmount  DECIMAL(18,2)     NOT NULL,
    ProblemLoanCount       INT               NOT NULL,

    CONSTRAINT PK_FactLoan
        PRIMARY KEY (LoanKey),

    CONSTRAINT UQ_FactLoan_LoanID
        UNIQUE (LoanID),

    CONSTRAINT FK_FactLoan_Date
        FOREIGN KEY (LoanDateKey)
        REFERENCES dbo.DimDate(DateKey),

    CONSTRAINT FK_FactLoan_Account
        FOREIGN KEY (AccountKey)
        REFERENCES dbo.DimAccount(AccountKey),

    CONSTRAINT FK_FactLoan_District
        FOREIGN KEY (DistrictKey)
        REFERENCES dbo.DimDistrict(DistrictKey),

    CONSTRAINT FK_FactLoan_LoanStatus
        FOREIGN KEY (LoanStatusKey)
        REFERENCES dbo.DimLoanStatus(LoanStatusKey),

    CONSTRAINT CK_FactLoan_LoanCount
        CHECK (LoanCount >= 0),

    CONSTRAINT CK_FactLoan_LoanAmount
        CHECK (LoanAmount >= 0),

    CONSTRAINT CK_FactLoan_Duration
        CHECK (LoanDurationMonths >= 0),

    CONSTRAINT CK_FactLoan_MonthlyPayment
        CHECK (MonthlyPayment >= 0),

    CONSTRAINT CK_FactLoan_ExpectedPayment
        CHECK (ExpectedPaymentAmount >= 0),

    CONSTRAINT CK_FactLoan_ProblemCount
        CHECK (ProblemLoanCount IN (0, 1))
);
GO

/*==============================================================
  3. Create indexes for Power BI and analytical queries
==============================================================*/

CREATE INDEX IX_FactLoan_LoanDateKey
ON dbo.FactLoan(LoanDateKey);
GO

CREATE INDEX IX_FactLoan_AccountKey
ON dbo.FactLoan(AccountKey);
GO

CREATE INDEX IX_FactLoan_DistrictKey
ON dbo.FactLoan(DistrictKey);
GO

CREATE INDEX IX_FactLoan_LoanStatusKey
ON dbo.FactLoan(LoanStatusKey);
GO

/*==============================================================
  4. Confirm required unknown members exist

  The unknown rows must exist because unmatched values are
  assigned surrogate key 0.
==============================================================*/

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DimAccount
    WHERE AccountKey = 0
)
BEGIN
    THROW 50001,
          'AccountKey 0 is missing from DimAccount.',
          1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DimDistrict
    WHERE DistrictKey = 0
)
BEGIN
    THROW 50002,
          'DistrictKey 0 is missing from DimDistrict.',
          1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DimLoanStatus
    WHERE LoanStatusKey = 0
)
BEGIN
    THROW 50003,
          'LoanStatusKey 0 is missing from DimLoanStatus.',
          1;
END;
GO

/*==============================================================
  5. Prepare the Loan source

  Assumptions:
      loan.date     is already DATE
      loan.amount   is the original loan amount
      loan.duration is the number of months
      loan.payments is the monthly payment
      loan.status   contains A, B, C or D
==============================================================*/

;WITH PreparedLoan AS
(
    SELECT
        l.loan_id AS LoanID,
        l.account_id AS AccountID,

        /* Convert DATE into YYYYMMDD integer DateKey */
        CONVERT
        (
            INT,
            CONVERT
            (
                CHAR(8),
                l.[date],
                112
            )
        ) AS LoanDateKey,

        /* Standardise loan status */
        COALESCE
        (
            NULLIF
            (
                UPPER
                (
                    LTRIM
                    (
                        RTRIM(l.[status])
                    )
                ),
                N''
            ),
            N'UNKNOWN'
        ) AS LoanStatusCode,

        /* Convert numerical source fields */
        COALESCE
        (
            TRY_CONVERT
            (
                DECIMAL(18,2),
                l.amount
            ),
            CONVERT(DECIMAL(18,2), 0)
        ) AS LoanAmount,

        COALESCE
        (
            TRY_CONVERT
            (
                INT,
                l.duration
            ),
            0
        ) AS LoanDurationMonths,

        COALESCE
        (
            TRY_CONVERT
            (
                DECIMAL(18,2),
                l.payments
            ),
            CONVERT(DECIMAL(18,2), 0)
        ) AS MonthlyPayment

    FROM CzechBank_DW.dbo.loan AS l

    WHERE l.loan_id IS NOT NULL
      AND l.account_id IS NOT NULL
      AND l.[date] IS NOT NULL
),

CalculatedLoan AS
(
    SELECT
        pl.LoanID,
        pl.AccountID,
        pl.LoanDateKey,
        pl.LoanStatusCode,
        pl.LoanAmount,
        pl.LoanDurationMonths,
        pl.MonthlyPayment,

        /* One source row represents one loan */
        CAST(1 AS INT) AS LoanCount,

        /* Duration multiplied by monthly payment */
        CONVERT
        (
            DECIMAL(18,2),
            pl.LoanDurationMonths * pl.MonthlyPayment
        ) AS ExpectedPaymentAmount

    FROM PreparedLoan AS pl
)

/*==============================================================
  6. Load FactLoan
==============================================================*/

INSERT INTO dbo.FactLoan
(
    LoanID,
    LoanDateKey,
    AccountKey,
    DistrictKey,
    LoanStatusKey,
    LoanCount,
    LoanAmount,
    LoanDurationMonths,
    MonthlyPayment,
    ExpectedPaymentAmount,
    ProblemLoanCount
)
SELECT
    cl.LoanID,
    cl.LoanDateKey,

    /* Map source AccountID to warehouse AccountKey */
    COALESCE
    (
        da.AccountKey,
        0
    ) AS AccountKey,

    /* Map source account district to DistrictKey */
    COALESCE
    (
        dd.DistrictKey,
        0
    ) AS DistrictKey,

    /* Map source loan status to LoanStatusKey */
    COALESCE
    (
        dls.LoanStatusKey,
        0
    ) AS LoanStatusKey,

    cl.LoanCount,
    cl.LoanAmount,
    cl.LoanDurationMonths,
    cl.MonthlyPayment,
    cl.ExpectedPaymentAmount,

    /* One problem-loan count for B or D status */
    CASE
        WHEN COALESCE(dls.ProblemFlag, 0) = 1
            THEN 1
        ELSE 0
    END AS ProblemLoanCount

FROM CalculatedLoan AS cl

/* Loan date must exist in DimDate */
INNER JOIN dbo.DimDate AS ddate
    ON cl.LoanDateKey = ddate.DateKey

/* Match the current Account dimension record */
LEFT JOIN dbo.DimAccount AS da
    ON cl.AccountID = da.AccountID
   AND da.IsCurrent = 1

/* Retrieve district_id from the source Account table */
LEFT JOIN CzechBank_DW.dbo.account AS sourceAccount
    ON cl.AccountID = sourceAccount.account_id

/* Map source district_id to warehouse DistrictKey */
LEFT JOIN dbo.DimDistrict AS dd
    ON sourceAccount.district_id = dd.DistrictID

/* Map Loan Status */
LEFT JOIN dbo.DimLoanStatus AS dls
    ON cl.LoanStatusCode = dls.LoanStatusCode

/* Prevent duplicate LoanID values */
WHERE NOT EXISTS
(
    SELECT 1

    FROM dbo.FactLoan AS existing

    WHERE existing.LoanID = cl.LoanID
);
GO

/*==============================================================
  7. Validate the FactLoan load
==============================================================*/

SELECT
    COUNT(*) AS FactLoanRows,

    COUNT(DISTINCT LoanID)
        AS DistinctLoanIDs,

    SUM(LoanCount)
        AS TotalLoanCount,

    SUM(LoanAmount)
        AS TotalLoanAmount,

    SUM(ExpectedPaymentAmount)
        AS TotalExpectedPaymentAmount,

    SUM(ProblemLoanCount)
        AS TotalProblemLoans

FROM dbo.FactLoan;
GO

/*==============================================================
  8. Compare source rows and FactLoan rows
==============================================================*/

SELECT
    COUNT(*) AS SourceLoanRows,
    COUNT(DISTINCT loan_id) AS DistinctSourceLoanIDs

FROM CzechBank_DW.dbo.loan;
GO

SELECT
    COUNT(*) AS FactLoanRows,
    COUNT(DISTINCT LoanID) AS DistinctFactLoanIDs

FROM dbo.FactLoan;
GO

/*==============================================================
  9. Check unknown dimension mappings
==============================================================*/

SELECT
    SUM
    (
        CASE
            WHEN AccountKey = 0 THEN 1
            ELSE 0
        END
    ) AS UnknownAccountRows,

    SUM
    (
        CASE
            WHEN DistrictKey = 0 THEN 1
            ELSE 0
        END
    ) AS UnknownDistrictRows,

    SUM
    (
        CASE
            WHEN LoanStatusKey = 0 THEN 1
            ELSE 0
        END
    ) AS UnknownLoanStatusRows

FROM dbo.FactLoan;
GO

/*==============================================================
  10. Display loaded Loan records
==============================================================*/

SELECT TOP 100
    fl.LoanKey,
    fl.LoanID,

    fl.LoanDateKey,
    dd.FullDate AS LoanDate,

    fl.AccountKey,
    da.AccountID,

    fl.DistrictKey,
    dis.DistrictID,
    dis.DistrictName,
    dis.RegionName,

    fl.LoanStatusKey,
    dls.LoanStatusCode,
    dls.LoanStatusDescription,
    dls.LoanStatusGroup,
    dls.ProblemFlag,

    fl.LoanCount,
    fl.LoanAmount,
    fl.LoanDurationMonths,
    fl.MonthlyPayment,
    fl.ExpectedPaymentAmount,
    fl.ProblemLoanCount

FROM dbo.FactLoan AS fl

INNER JOIN dbo.DimDate AS dd
    ON fl.LoanDateKey = dd.DateKey

LEFT JOIN dbo.DimAccount AS da
    ON fl.AccountKey = da.AccountKey

LEFT JOIN dbo.DimDistrict AS dis
    ON fl.DistrictKey = dis.DistrictKey

LEFT JOIN dbo.DimLoanStatus AS dls
    ON fl.LoanStatusKey = dls.LoanStatusKey

ORDER BY
    dd.FullDate,
    fl.LoanID;
GO

/*==============================================================
  11. Summarise Loans by status
==============================================================*/

SELECT
    dls.LoanStatusCode,
    dls.LoanStatusDescription,
    dls.LoanStatusGroup,
    dls.ProblemFlag,

    SUM(fl.LoanCount) AS LoanCount,
    SUM(fl.LoanAmount) AS TotalLoanAmount,

    AVG
    (
        fl.LoanAmount
    ) AS AverageLoanAmount,

    SUM
    (
        fl.ExpectedPaymentAmount
    ) AS TotalExpectedPaymentAmount,

    SUM
    (
        fl.ProblemLoanCount
    ) AS ProblemLoanCount

FROM dbo.FactLoan AS fl

INNER JOIN dbo.DimLoanStatus AS dls
    ON fl.LoanStatusKey = dls.LoanStatusKey

GROUP BY
    dls.LoanStatusCode,
    dls.LoanStatusDescription,
    dls.LoanStatusGroup,
    dls.ProblemFlag

ORDER BY dls.LoanStatusCode;
GO