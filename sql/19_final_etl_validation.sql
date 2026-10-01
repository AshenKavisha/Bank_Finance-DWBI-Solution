USE CzechBank_DW;
GO

/* =========================================================
   1. Validate row counts through the ETL pipeline
   ========================================================= */

SELECT
    'Account transformation' AS ValidationCheck,
    (SELECT COUNT_BIG(*) FROM stg.account) AS SourceRows,
    (SELECT COUNT_BIG(*) FROM stg.account_clean) AS TargetRows,
    CASE
        WHEN (SELECT COUNT_BIG(*) FROM stg.account) =
             (SELECT COUNT_BIG(*) FROM stg.account_clean)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS ValidationStatus

UNION ALL

SELECT
    'Client transformation',
    (SELECT COUNT_BIG(*) FROM stg.client),
    (SELECT COUNT_BIG(*) FROM stg.client_clean),
    CASE
        WHEN (SELECT COUNT_BIG(*) FROM stg.client) =
             (SELECT COUNT_BIG(*) FROM stg.client_clean)
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'District transformation',
    (SELECT COUNT_BIG(*) FROM stg.district),
    (SELECT COUNT_BIG(*) FROM stg.district_clean),
    CASE
        WHEN (SELECT COUNT_BIG(*) FROM stg.district) =
             (SELECT COUNT_BIG(*) FROM stg.district_clean)
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Loan transformation',
    (SELECT COUNT_BIG(*) FROM stg.loan),
    (SELECT COUNT_BIG(*) FROM stg.loan_clean),
    CASE
        WHEN (SELECT COUNT_BIG(*) FROM stg.loan) =
             (SELECT COUNT_BIG(*) FROM stg.loan_clean)
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Transaction transformation',
    (SELECT COUNT_BIG(*) FROM stg.trans),
    (SELECT COUNT_BIG(*) FROM stg.transaction_clean),
    CASE
        WHEN (SELECT COUNT_BIG(*) FROM stg.trans) =
             (SELECT COUNT_BIG(*) FROM stg.transaction_clean)
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Loan fact loading',
    (SELECT COUNT_BIG(*) FROM stg.loan_clean),
    (SELECT COUNT_BIG(*) FROM dbo.FactLoan),
    CASE
        WHEN (SELECT COUNT_BIG(*) FROM stg.loan_clean) =
             (SELECT COUNT_BIG(*) FROM dbo.FactLoan)
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Transaction fact loading',
    (SELECT COUNT_BIG(*) FROM stg.transaction_clean),
    (SELECT COUNT_BIG(*) FROM dbo.FactTransaction),
    CASE
        WHEN (SELECT COUNT_BIG(*) FROM stg.transaction_clean) =
             (SELECT COUNT_BIG(*) FROM dbo.FactTransaction)
        THEN 'PASS'
        ELSE 'FAIL'
    END;
GO


/* =========================================================
   2. Validate fact-table dimension relationships
   ========================================================= */

SELECT
    'FactLoan invalid AccountKey' AS ValidationCheck,
    COUNT_BIG(*) AS InvalidRows
FROM dbo.FactLoan AS fact
LEFT JOIN dbo.DimAccount AS dimension
    ON fact.AccountKey = dimension.AccountKey
WHERE dimension.AccountKey IS NULL

UNION ALL

SELECT
    'FactLoan invalid DistrictKey',
    COUNT_BIG(*)
FROM dbo.FactLoan AS fact
LEFT JOIN dbo.DimDistrict AS dimension
    ON fact.DistrictKey = dimension.DistrictKey
WHERE dimension.DistrictKey IS NULL

UNION ALL

SELECT
    'FactLoan invalid LoanStatusKey',
    COUNT_BIG(*)
FROM dbo.FactLoan AS fact
LEFT JOIN dbo.DimLoanStatus AS dimension
    ON fact.LoanStatusKey = dimension.LoanStatusKey
WHERE dimension.LoanStatusKey IS NULL

UNION ALL

SELECT
    'FactTransaction invalid AccountKey',
    COUNT_BIG(*)
FROM dbo.FactTransaction AS fact
LEFT JOIN dbo.DimAccount AS dimension
    ON fact.AccountKey = dimension.AccountKey
WHERE dimension.AccountKey IS NULL

UNION ALL

SELECT
    'FactTransaction invalid DistrictKey',
    COUNT_BIG(*)
FROM dbo.FactTransaction AS fact
LEFT JOIN dbo.DimDistrict AS dimension
    ON fact.DistrictKey = dimension.DistrictKey
WHERE dimension.DistrictKey IS NULL

UNION ALL

SELECT
    'FactTransaction invalid TransactionTypeKey',
    COUNT_BIG(*)
FROM dbo.FactTransaction AS fact
LEFT JOIN dbo.DimTransactionType AS dimension
    ON fact.TransactionTypeKey = dimension.TransactionTypeKey
WHERE dimension.TransactionTypeKey IS NULL

UNION ALL

SELECT
    'FactTransaction invalid OperationKey',
    COUNT_BIG(*)
FROM dbo.FactTransaction AS fact
LEFT JOIN dbo.DimOperation AS dimension
    ON fact.OperationKey = dimension.OperationKey
WHERE dimension.OperationKey IS NULL;
GO

/* =========================================================
   3. Validate warehouse-to-data-mart reconciliation
   ========================================================= */

SELECT
    'Transaction data mart' AS ValidationCheck,

    (SELECT SUM(CAST(TransactionCount AS BIGINT))
     FROM dbo.FactTransaction) AS WarehouseValue,

    (SELECT SUM(TotalTransactions)
     FROM mart.MonthlyTransactionPerformance) AS DataMartValue,

    CASE
        WHEN
        (
            SELECT SUM(CAST(TransactionCount AS BIGINT))
            FROM dbo.FactTransaction
        )
        =
        (
            SELECT SUM(TotalTransactions)
            FROM mart.MonthlyTransactionPerformance
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS ValidationStatus

UNION ALL

SELECT
    'Loan data mart',

    (SELECT SUM(LoanCount)
     FROM dbo.FactLoan),

    (SELECT SUM(TotalLoans)
     FROM mart.DistrictLoanPerformance),

    CASE
        WHEN
        (
            SELECT SUM(LoanCount)
            FROM dbo.FactLoan
        )
        =
        (
            SELECT SUM(TotalLoans)
            FROM mart.DistrictLoanPerformance
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Problem-loan data mart',

    (SELECT SUM(ProblemLoanCount)
     FROM dbo.FactLoan),

    (SELECT SUM(ProblemLoans)
     FROM mart.DistrictLoanPerformance),

    CASE
        WHEN
        (
            SELECT SUM(ProblemLoanCount)
            FROM dbo.FactLoan
        )
        =
        (
            SELECT SUM(ProblemLoans)
            FROM mart.DistrictLoanPerformance
        )
        THEN 'PASS'
        ELSE 'FAIL'
    END;
GO