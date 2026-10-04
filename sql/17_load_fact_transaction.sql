USE CzechBank_DW;
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

/* Insert only transactions not already in FactTransaction */
INSERT INTO dbo.FactTransaction
(
    TransactionID,
    DateKey,
    AccountKey,
    DistrictKey,
    TransactionTypeKey,
    OperationKey,
    TransactionCount,
    TransactionAmount,
    InflowAmount,
    OutflowAmount,
    SignedAmount,
    BalanceAfterTransaction
)
SELECT
    source.TransactionID,
    source.DateKey,
    account.AccountKey,
    district.DistrictKey,
    transactionType.TransactionTypeKey,
    operation.OperationKey,
    source.TransactionCount,
    source.TransactionAmount,
    source.InflowAmount,
    source.OutflowAmount,
    source.SignedAmount,
    source.BalanceAfterTransaction
FROM stg.transaction_clean AS source
INNER JOIN dbo.DimDate AS transactionDate
    ON source.DateKey = transactionDate.DateKey
INNER JOIN dbo.DimAccount AS account
    ON source.AccountID = account.AccountID
   AND account.EffectiveTo = '9999-12-31'
INNER JOIN dbo.DimDistrict AS district
    ON source.DistrictID = district.DistrictID
INNER JOIN dbo.DimTransactionType AS transactionType
    ON source.TransactionTypeCode =
       transactionType.TransactionTypeCode
INNER JOIN dbo.DimOperation AS operation
    ON source.OperationCode = operation.OperationCode
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.FactTransaction AS target
    WHERE target.TransactionID = source.TransactionID
);

DECLARE @InsertedTransactions BIGINT = @@ROWCOUNT;

COMMIT TRANSACTION;

SELECT
    @InsertedTransactions AS InsertedTransactions;
GO

/* Validate FactTransaction loading */

SELECT
    COUNT_BIG(*) AS TotalFactTransactions,
    SUM(CAST(TransactionCount AS BIGINT)) AS TotalTransactionCount,
    SUM(TransactionAmount) AS TotalTransactionAmount,
    SUM(InflowAmount) AS TotalInflow,
    SUM(OutflowAmount) AS TotalOutflow,
    SUM(SignedAmount) AS NetCashFlow
FROM dbo.FactTransaction;
GO

/* Confirm every clean transaction exists */
SELECT COUNT_BIG(*) AS MissingTransactionsAfterLoad
FROM stg.transaction_clean AS source
LEFT JOIN dbo.FactTransaction AS target
    ON source.TransactionID = target.TransactionID
WHERE target.TransactionKey IS NULL;
GO

/* Check duplicate transaction IDs */
SELECT
    TransactionID,
    COUNT_BIG(*) AS DuplicateCount
FROM dbo.FactTransaction
GROUP BY TransactionID
HAVING COUNT_BIG(*) > 1;
GO

/* Check missing balances preserved */
SELECT COUNT_BIG(*) AS MissingBalancesPreserved
FROM dbo.FactTransaction
WHERE BalanceAfterTransaction IS NULL;
GO

/* Check broken dimension relationships */
SELECT
    SUM(CASE WHEN transactionDate.DateKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidDateKeys,
    SUM(CASE WHEN account.AccountKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidAccountKeys,
    SUM(CASE WHEN district.DistrictKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidDistrictKeys,
    SUM(CASE WHEN transactionType.TransactionTypeKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidTransactionTypeKeys,
    SUM(CASE WHEN operation.OperationKey IS NULL THEN 1 ELSE 0 END)
        AS InvalidOperationKeys
FROM dbo.FactTransaction AS fact
LEFT JOIN dbo.DimDate AS transactionDate
    ON fact.DateKey = transactionDate.DateKey
LEFT JOIN dbo.DimAccount AS account
    ON fact.AccountKey = account.AccountKey
LEFT JOIN dbo.DimDistrict AS district
    ON fact.DistrictKey = district.DistrictKey
LEFT JOIN dbo.DimTransactionType AS transactionType
    ON fact.TransactionTypeKey = transactionType.TransactionTypeKey
LEFT JOIN dbo.DimOperation AS operation
    ON fact.OperationKey = operation.OperationKey;
GO

/* Transaction summary using English descriptions */
SELECT
    transactionType.TransactionTypeName,
    transactionType.CashFlowDirection,
    COUNT_BIG(*) AS TransactionRecords,
    SUM(fact.InflowAmount) AS TotalInflow,
    SUM(fact.OutflowAmount) AS TotalOutflow,
    SUM(fact.SignedAmount) AS NetAmount
FROM dbo.FactTransaction AS fact
INNER JOIN dbo.DimTransactionType AS transactionType
    ON fact.TransactionTypeKey =
       transactionType.TransactionTypeKey
GROUP BY
    transactionType.TransactionTypeName,
    transactionType.CashFlowDirection
ORDER BY TransactionRecords DESC;
GO