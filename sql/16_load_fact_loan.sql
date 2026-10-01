USE CzechBank_DW;
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

/* Update existing loan facts */
UPDATE target
SET
    target.LoanDateKey = source.LoanDateKey,
    target.AccountKey = account.AccountKey,
    target.DistrictKey = district.DistrictKey,
    target.LoanStatusKey = status.LoanStatusKey,
    target.LoanCount = source.LoanCount,
    target.LoanAmount = source.LoanAmount,
    target.LoanDurationMonths = source.LoanDurationMonths,
    target.MonthlyPayment = source.MonthlyPayment,
    target.ExpectedPaymentAmount = source.ExpectedPaymentAmount,
    target.ProblemLoanCount = source.ProblemLoanCount
FROM dbo.FactLoan AS target
INNER JOIN stg.loan_clean AS source
    ON target.LoanID = source.LoanID
INNER JOIN dbo.DimDate AS loanDate
    ON source.LoanDateKey = loanDate.DateKey
INNER JOIN dbo.DimAccount AS account
    ON source.AccountID = account.AccountID
   AND account.EffectiveTo = '9999-12-31'
INNER JOIN dbo.DimDistrict AS district
    ON source.DistrictID = district.DistrictID
INNER JOIN dbo.DimLoanStatus AS status
    ON source.LoanStatusCode = status.LoanStatusCode;

DECLARE @UpdatedLoans INT = @@ROWCOUNT;

/* Insert only loans that do not already exist */
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
    source.LoanID,
    source.LoanDateKey,
    account.AccountKey,
    district.DistrictKey,
    status.LoanStatusKey,
    source.LoanCount,
    source.LoanAmount,
    source.LoanDurationMonths,
    source.MonthlyPayment,
    source.ExpectedPaymentAmount,
    source.ProblemLoanCount
FROM stg.loan_clean AS source
INNER JOIN dbo.DimDate AS loanDate
    ON source.LoanDateKey = loanDate.DateKey
INNER JOIN dbo.DimAccount AS account
    ON source.AccountID = account.AccountID
   AND account.EffectiveTo = '9999-12-31'
INNER JOIN dbo.DimDistrict AS district
    ON source.DistrictID = district.DistrictID
INNER JOIN dbo.DimLoanStatus AS status
    ON source.LoanStatusCode = status.LoanStatusCode
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.FactLoan AS target
    WHERE target.LoanID = source.LoanID
);

DECLARE @InsertedLoans INT = @@ROWCOUNT;

COMMIT TRANSACTION;

SELECT
    @UpdatedLoans AS UpdatedLoans,
    @InsertedLoans AS InsertedLoans;
GO

/* Validate FactLoan loading */

SELECT
    COUNT(*) AS TotalFactLoans,
    SUM(LoanCount) AS TotalLoanCount,
    SUM(ProblemLoanCount) AS TotalProblemLoans,
    SUM(LoanAmount) AS TotalLoanAmount
FROM dbo.FactLoan;
GO

/* Confirm every clean loan exists in FactLoan */
SELECT COUNT(*) AS MissingLoansAfterLoad
FROM stg.loan_clean AS source
LEFT JOIN dbo.FactLoan AS target
    ON source.LoanID = target.LoanID
WHERE target.LoanKey IS NULL;
GO

/* Check for duplicate loan business IDs */
SELECT
    LoanID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactLoan
GROUP BY LoanID
HAVING COUNT(*) > 1;
GO

/* Check broken dimension relationships */
SELECT
    SUM(CASE WHEN account.AccountKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidAccountKeys,
    SUM(CASE WHEN district.DistrictKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidDistrictKeys,
    SUM(CASE WHEN status.LoanStatusKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidStatusKeys,
    SUM(CASE WHEN loanDate.DateKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidDateKeys
FROM dbo.FactLoan AS fact
LEFT JOIN dbo.DimAccount AS account
    ON fact.AccountKey = account.AccountKey
LEFT JOIN dbo.DimDistrict AS district
    ON fact.DistrictKey = district.DistrictKey
LEFT JOIN dbo.DimLoanStatus AS status
    ON fact.LoanStatusKey = status.LoanStatusKey
LEFT JOIN dbo.DimDate AS loanDate
    ON fact.LoanDateKey = loanDate.DateKey;
GO

SELECT
    status.LoanStatusCode,
    status.LoanStatusDescription,
    COUNT(*) AS LoanRecords,
    SUM(fact.ProblemLoanCount) AS ProblemLoans,
    SUM(fact.LoanAmount) AS TotalLoanAmount
FROM dbo.FactLoan AS fact
INNER JOIN dbo.DimLoanStatus AS status
    ON fact.LoanStatusKey = status.LoanStatusKey
GROUP BY
    status.LoanStatusCode,
    status.LoanStatusDescription
ORDER BY status.LoanStatusCode;
GO