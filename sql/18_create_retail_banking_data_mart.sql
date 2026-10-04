USE CzechBank_DW;
GO

/* Create the data-mart schema if it does not exist */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = 'mart'
)
BEGIN
    EXEC('CREATE SCHEMA mart');
END;
GO

/* =========================================================
   1. Monthly transaction performance
   ========================================================= */

DROP TABLE IF EXISTS mart.MonthlyTransactionPerformance;
GO

SELECT
    dateDimension.[Year],
    dateDimension.MonthNumber,
    dateDimension.MonthName,
    dateDimension.[Quarter],

    CONCAT(
        dateDimension.[Year],
        '-',
        RIGHT('0' + CAST(dateDimension.MonthNumber AS VARCHAR(2)), 2)
    ) AS YearMonthLabel,

    SUM(CAST(fact.TransactionCount AS BIGINT))
        AS TotalTransactions,

    COUNT(DISTINCT fact.AccountKey)
        AS ActiveAccounts,

    SUM(fact.TransactionAmount)
        AS TotalTransactionAmount,

    SUM(fact.InflowAmount)
        AS TotalInflow,

    SUM(fact.OutflowAmount)
        AS TotalOutflow,

    SUM(fact.SignedAmount)
        AS NetCashFlow,

    CAST(
        SUM(fact.TransactionAmount) /
        NULLIF(SUM(fact.TransactionCount), 0)
        AS DECIMAL(18,2)
    ) AS AverageTransactionAmount

INTO mart.MonthlyTransactionPerformance
FROM dbo.FactTransaction AS fact
INNER JOIN dbo.DimDate AS dateDimension
    ON fact.DateKey = dateDimension.DateKey
GROUP BY
    dateDimension.[Year],
    dateDimension.MonthNumber,
    dateDimension.MonthName,
    dateDimension.[Quarter];
GO

ALTER TABLE mart.MonthlyTransactionPerformance
ADD CONSTRAINT PK_MonthlyTransactionPerformance
PRIMARY KEY ([Year], MonthNumber);
GO

/* =========================================================
   2. District loan performance
   ========================================================= */

DROP TABLE IF EXISTS mart.DistrictLoanPerformance;
GO

SELECT
    district.DistrictKey,
    district.DistrictID,
    district.DistrictName,
    district.RegionName,
    district.Population,
    district.AverageSalary,
    district.UnemploymentMeasure,
    district.EntrepreneurMeasure,
    district.CrimeMeasure,

    SUM(fact.LoanCount)
        AS TotalLoans,

    COUNT(DISTINCT fact.AccountKey)
        AS BorrowingAccounts,

    SUM(fact.LoanAmount)
        AS TotalLoanAmount,

    CAST(
        SUM(fact.LoanAmount) /
        NULLIF(SUM(fact.LoanCount), 0)
        AS DECIMAL(18,2)
    ) AS AverageLoanAmount,

    SUM(fact.MonthlyPayment)
        AS TotalMonthlyPayments,

    SUM(fact.ExpectedPaymentAmount)
        AS TotalExpectedPaymentAmount,

    SUM(fact.ProblemLoanCount)
        AS ProblemLoans,

    CAST(
        100.0 * SUM(fact.ProblemLoanCount) /
        NULLIF(SUM(fact.LoanCount), 0)
        AS DECIMAL(6,2)
    ) AS ProblemLoanPercentage

INTO mart.DistrictLoanPerformance
FROM dbo.FactLoan AS fact
INNER JOIN dbo.DimDistrict AS district
    ON fact.DistrictKey = district.DistrictKey
WHERE district.DistrictID <> -1
GROUP BY
    district.DistrictKey,
    district.DistrictID,
    district.DistrictName,
    district.RegionName,
    district.Population,
    district.AverageSalary,
    district.UnemploymentMeasure,
    district.EntrepreneurMeasure,
    district.CrimeMeasure;
GO

ALTER TABLE mart.DistrictLoanPerformance
ADD CONSTRAINT PK_DistrictLoanPerformance
PRIMARY KEY (DistrictKey);
GO


/* =========================================================
   Validate data-mart tables
   ========================================================= */

SELECT
    'MonthlyTransactionPerformance' AS DataMartTable,
    COUNT(*) AS SummaryRows,
    SUM(TotalTransactions) AS ReconciledRecordCount
FROM mart.MonthlyTransactionPerformance

UNION ALL

SELECT
    'DistrictLoanPerformance',
    COUNT(*),
    SUM(TotalLoans)
FROM mart.DistrictLoanPerformance;
GO

/* Reconcile transaction totals */
SELECT
    (SELECT SUM(TransactionCount)
     FROM dbo.FactTransaction) AS WarehouseTransactions,

    (SELECT SUM(TotalTransactions)
     FROM mart.MonthlyTransactionPerformance) AS DataMartTransactions;
GO

/* Reconcile loan totals */
SELECT
    (SELECT SUM(LoanCount)
     FROM dbo.FactLoan) AS WarehouseLoans,

    (SELECT SUM(TotalLoans)
     FROM mart.DistrictLoanPerformance) AS DataMartLoans,

    (SELECT SUM(ProblemLoanCount)
     FROM dbo.FactLoan) AS WarehouseProblemLoans,

    (SELECT SUM(ProblemLoans)
     FROM mart.DistrictLoanPerformance) AS DataMartProblemLoans;
GO

SELECT TOP 12 *
FROM mart.MonthlyTransactionPerformance
ORDER BY [Year], MonthNumber;
GO

SELECT TOP 10 *
FROM mart.DistrictLoanPerformance
ORDER BY ProblemLoanPercentage DESC, TotalLoanAmount DESC;
GO