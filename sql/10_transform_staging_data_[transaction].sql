USE CzechBank_DW;
GO

/* 1. Inspect transaction columns */
SELECT
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'trans'
ORDER BY ORDINAL_POSITION;
GO

/* 2. Inspect transaction types */
SELECT
    type,
    COUNT_BIG(*) AS TransactionCount,
    SUM(CAST(amount AS DECIMAL(18,2))) AS TotalAmount
FROM stg.trans
GROUP BY type
ORDER BY TransactionCount DESC;
GO

/* 3. Inspect transaction operations */
SELECT
    operation,
    COUNT_BIG(*) AS TransactionCount
FROM stg.trans
GROUP BY operation
ORDER BY TransactionCount DESC;
GO

/* 4. View current transaction-type dimension mappings */
SELECT *
FROM dbo.DimTransactionType
ORDER BY TransactionTypeKey;
GO

/* 5. View current operation dimension mappings */
SELECT *
FROM dbo.DimOperation
ORDER BY OperationKey;
GO

/* 6. Check data-quality problems */
SELECT
    COUNT_BIG(*) AS TotalTransactions,

    SUM(CASE WHEN trans_id IS NULL THEN 1 ELSE 0 END)
        AS MissingTransactionIDs,

    SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END)
        AS MissingAccountIDs,

    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END)
        AS MissingDates,

    SUM(CASE WHEN type IS NULL OR LTRIM(RTRIM(type)) = ''
             THEN 1 ELSE 0 END)
        AS MissingTypes,

    SUM(CASE WHEN operation IS NULL OR LTRIM(RTRIM(operation)) = ''
             THEN 1 ELSE 0 END)
        AS MissingOperations,

    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END)
        AS MissingAmounts,

    SUM(CASE WHEN balance IS NULL THEN 1 ELSE 0 END)
        AS MissingBalances
FROM stg.trans;
GO

/* 7. Check account references */
SELECT COUNT_BIG(*) AS InvalidAccountReferences
FROM stg.trans AS t
LEFT JOIN stg.account AS a
    ON t.account_id = a.account_id
WHERE a.account_id IS NULL;
GO

/* 8. Check duplicate transaction IDs */
SELECT
    trans_id,
    COUNT_BIG(*) AS DuplicateCount
FROM stg.trans
GROUP BY trans_id
HAVING COUNT_BIG(*) > 1;
GO

/* =========================================================
   Transform Transaction data
   ========================================================= */

USE CzechBank_DW;
GO

DROP TABLE IF EXISTS stg.transaction_clean;
GO

WITH DeduplicatedTransactions AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY trans_id
            ORDER BY ETL_LoadDateTime DESC
        ) AS DuplicateRowNumber
    FROM stg.trans
)

SELECT
    t.trans_id AS TransactionID,
    t.account_id AS AccountID,
    a.DistrictID,

    t.[date] AS TransactionDate,

    -- Convert the date into the warehouse DateKey format: YYYYMMDD
    CONVERT(INT, CONVERT(CHAR(8), t.[date], 112)) AS DateKey,

    -- Standardize transaction type
    CASE UPPER(LTRIM(RTRIM(t.[type])))
        WHEN 'PRIJEM' THEN 'PRIJEM'
        WHEN 'VYDAJ'  THEN 'VYDAJ'
        WHEN 'VYBER'  THEN 'VYBER'
        ELSE 'UNKNOWN'
    END AS TransactionTypeCode,

    -- Missing operations are retained as UNKNOWN
    COALESCE(
        NULLIF(UPPER(LTRIM(RTRIM(t.operation))), ''),
        'UNKNOWN'
    ) AS OperationCode,

    CAST(t.amount AS DECIMAL(18,2)) AS TransactionAmount,

    -- Incoming amount
    CAST(
        CASE
            WHEN UPPER(LTRIM(RTRIM(t.[type]))) = 'PRIJEM'
                THEN t.amount
            ELSE 0
        END
        AS DECIMAL(18,2)
    ) AS InflowAmount,

    -- Outgoing amount
    CAST(
        CASE
            WHEN UPPER(LTRIM(RTRIM(t.[type]))) IN ('VYDAJ', 'VYBER')
                THEN t.amount
            ELSE 0
        END
        AS DECIMAL(18,2)
    ) AS OutflowAmount,

    -- Positive for incoming and negative for outgoing
    CAST(
        CASE
            WHEN UPPER(LTRIM(RTRIM(t.[type]))) = 'PRIJEM'
                THEN t.amount
            WHEN UPPER(LTRIM(RTRIM(t.[type]))) IN ('VYDAJ', 'VYBER')
                THEN -t.amount
            ELSE 0
        END
        AS DECIMAL(18,2)
    ) AS SignedAmount,

    -- Preserve missing balances instead of inventing values
    CAST(t.balance AS DECIMAL(18,2)) AS BalanceAfterTransaction,

    COALESCE(
        NULLIF(UPPER(LTRIM(RTRIM(t.k_symbol))), ''),
        'UNKNOWN'
    ) AS PurposeCode,

    CAST(1 AS INT) AS TransactionCount,

    t.ETL_LoadDateTime

INTO stg.transaction_clean
FROM DeduplicatedTransactions AS t
INNER JOIN stg.account_clean AS a
    ON t.account_id = a.AccountID
WHERE t.DuplicateRowNumber = 1
  AND t.trans_id IS NOT NULL
  AND t.account_id IS NOT NULL
  AND t.[date] IS NOT NULL
  AND t.amount IS NOT NULL;
GO

/* Validate transaction transformation */

SELECT
    (SELECT COUNT_BIG(*) FROM stg.trans) AS SourceTransactions,
    (SELECT COUNT_BIG(*) FROM stg.transaction_clean) AS CleanTransactions;
GO

SELECT
    TransactionTypeCode,
    COUNT_BIG(*) AS TransactionCount,
    SUM(TransactionAmount) AS TotalAmount,
    SUM(InflowAmount) AS TotalInflow,
    SUM(OutflowAmount) AS TotalOutflow,
    SUM(SignedAmount) AS NetAmount
FROM stg.transaction_clean
GROUP BY TransactionTypeCode
ORDER BY TransactionTypeCode;
GO

SELECT
    OperationCode,
    COUNT_BIG(*) AS TransactionCount
FROM stg.transaction_clean
GROUP BY OperationCode
ORDER BY TransactionCount DESC;
GO

SELECT
    COUNT_BIG(*) AS MissingBalancesPreserved
FROM stg.transaction_clean
WHERE BalanceAfterTransaction IS NULL;
GO

SELECT
    TransactionID,
    COUNT_BIG(*) AS DuplicateCount
FROM stg.transaction_clean
GROUP BY TransactionID
HAVING COUNT_BIG(*) > 1;
GO
