USE CzechBank_DW;
GO

/* View source loan data */
SELECT TOP 20
    loan_id,
    account_id,
    date AS LoanDate,
    amount,
    duration,
    payments,
    status
FROM stg.loan
ORDER BY loan_id;
GO

/* Inspect source loan-status codes */
SELECT
    status AS SourceStatus,
    COUNT(*) AS NumberOfLoans,
    SUM(amount) AS TotalLoanAmount
FROM stg.loan
GROUP BY status
ORDER BY status;
GO

/* Inspect Member 2's loan-status mapping */
SELECT
    LoanStatusCode,
    LoanStatusDescription,
    LoanStatusGroup,
    ProblemFlag
FROM dbo.DimLoanStatus
ORDER BY LoanStatusKey;
GO

/* Check invalid monetary and duration values */
SELECT
    COUNT(*) AS InvalidLoanRecords
FROM stg.loan
WHERE amount <= 0
   OR duration <= 0
   OR payments <= 0;
GO

/* Check loans without valid accounts */
SELECT
    COUNT(*) AS LoansWithoutValidAccount
FROM stg.loan AS loan
LEFT JOIN stg.account_clean AS account
    ON loan.account_id = account.AccountID
WHERE account.AccountID IS NULL;
GO

/* Check duplicate loan identifiers */
SELECT
    loan_id,
    COUNT(*) AS DuplicateCount
FROM stg.loan
GROUP BY loan_id
HAVING COUNT(*) > 1;
GO

/* =========================================================
   Transform loan data
   ========================================================= */

DROP TABLE IF EXISTS stg.loan_clean;
GO

WITH LoanSource AS
(
    SELECT
        loan_id,
        account_id,
        date,
        amount,
        duration,
        payments,
        status,
        ETL_LoadDateTime,

        ROW_NUMBER() OVER
        (
            PARTITION BY loan_id
            ORDER BY ETL_LoadDateTime DESC
        ) AS DuplicateRowNumber

    FROM stg.loan
)

SELECT
    loan.loan_id AS LoanID,
    loan.account_id AS AccountID,

    -- District is obtained through the associated account
    COALESCE(account.DistrictID, -1) AS DistrictID,

    loan.date AS LoanDate,

    -- Convert date to the warehouse YYYYMMDD date key
    CASE
        WHEN loan.date IS NOT NULL
        THEN CONVERT(INT, CONVERT(CHAR(8), loan.date, 112))
        ELSE 19000101
    END AS LoanDateKey,

    -- Clean and standardize status code
    CASE UPPER(LTRIM(RTRIM(loan.status)))
        WHEN 'A' THEN 'A'
        WHEN 'B' THEN 'B'
        WHEN 'C' THEN 'C'
        WHEN 'D' THEN 'D'
        ELSE 'UNKNOWN'
    END AS LoanStatusCode,

    CASE UPPER(LTRIM(RTRIM(loan.status)))
        WHEN 'A' THEN 'Completed Without Repayment Problems'
        WHEN 'B' THEN 'Completed With Repayment Problems'
        WHEN 'C' THEN 'Active Without Current Repayment Problems'
        WHEN 'D' THEN 'Active With Current Debt'
        ELSE 'Unknown Loan Status'
    END AS LoanStatusDescription,

    CASE UPPER(LTRIM(RTRIM(loan.status)))
        WHEN 'A' THEN 'Completed'
        WHEN 'B' THEN 'Completed'
        WHEN 'C' THEN 'Active'
        WHEN 'D' THEN 'Active'
        ELSE 'Unknown'
    END AS LoanStatusGroup,

    -- Convert floating-point money into fixed decimal values
    CAST(loan.amount AS DECIMAL(18,2)) AS LoanAmount,
    loan.duration AS LoanDurationMonths,
    CAST(loan.payments AS DECIMAL(18,2)) AS MonthlyPayment,

    -- Derived expected amount over the complete loan duration
    CAST(
        loan.payments * loan.duration
        AS DECIMAL(18,2)
    ) AS ExpectedPaymentAmount,

    -- Each source record represents one loan
    1 AS LoanCount,

    -- Problem-loan indicator
    CASE
        WHEN UPPER(LTRIM(RTRIM(loan.status))) IN ('B', 'D')
        THEN 1
        ELSE 0
    END AS ProblemLoanCount,

    loan.ETL_LoadDateTime

INTO stg.loan_clean
FROM LoanSource AS loan

LEFT JOIN stg.account_clean AS account
    ON loan.account_id = account.AccountID

WHERE loan.DuplicateRowNumber = 1
  AND loan.loan_id IS NOT NULL
  AND loan.amount > 0
  AND loan.duration > 0
  AND loan.payments > 0;
GO


/* Row-count comparison */
SELECT 'Original Loans' AS DataStage, COUNT(*) AS NumberOfRows
FROM stg.loan

UNION ALL

SELECT 'Transformed Loans', COUNT(*)
FROM stg.loan_clean;
GO

/* View transformed records */
SELECT TOP 20 *
FROM stg.loan_clean
ORDER BY LoanID;
GO

/* Validate status and problem-loan counts */
SELECT
    LoanStatusCode,
    LoanStatusGroup,
    COUNT(*) AS NumberOfLoans,
    SUM(ProblemLoanCount) AS ProblemLoans,
    SUM(LoanAmount) AS TotalLoanAmount
FROM stg.loan_clean
GROUP BY LoanStatusCode, LoanStatusGroup
ORDER BY LoanStatusCode;
GO

/* Validate totals */
SELECT
    COUNT(*) AS TotalLoans,
    SUM(LoanCount) AS LoanCountMeasure,
    SUM(ProblemLoanCount) AS TotalProblemLoans,
    SUM(LoanAmount) AS TotalLoanAmount,
    SUM(ExpectedPaymentAmount) AS TotalExpectedPayments
FROM stg.loan_clean;
GO

/* Check duplicate IDs */
SELECT LoanID, COUNT(*) AS DuplicateCount
FROM stg.loan_clean
GROUP BY LoanID
HAVING COUNT(*) > 1;
GO