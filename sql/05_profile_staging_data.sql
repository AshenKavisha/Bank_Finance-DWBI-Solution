USE CzechBank_DW;
GO

/* 1. Duplicate primary identifiers */
SELECT 'account' AS TableName, account_id AS DuplicateID, COUNT(*) AS DuplicateCount
FROM stg.account
GROUP BY account_id
HAVING COUNT(*) > 1;

SELECT 'client' AS TableName, client_id AS DuplicateID, COUNT(*) AS DuplicateCount
FROM stg.client
GROUP BY client_id
HAVING COUNT(*) > 1;

SELECT 'loan' AS TableName, loan_id AS DuplicateID, COUNT(*) AS DuplicateCount
FROM stg.loan
GROUP BY loan_id
HAVING COUNT(*) > 1;

SELECT 'transaction' AS TableName, trans_id AS DuplicateID, COUNT(*) AS DuplicateCount
FROM stg.trans
GROUP BY trans_id
HAVING COUNT(*) > 1;
GO

/* 2. Missing values in important columns */
SELECT
    SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END) AS MissingAccountID,
    SUM(CASE WHEN district_id IS NULL THEN 1 ELSE 0 END) AS MissingDistrictID,
    SUM(CASE WHEN frequency IS NULL OR LTRIM(RTRIM(frequency)) = ''
             THEN 1 ELSE 0 END) AS MissingFrequency,
    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END) AS MissingOpenDate
FROM stg.account;

SELECT
    SUM(CASE WHEN trans_id IS NULL THEN 1 ELSE 0 END) AS MissingTransactionID,
    SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END) AS MissingAccountID,
    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END) AS MissingTransactionDate,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS MissingAmount,
    SUM(CASE WHEN balance IS NULL THEN 1 ELSE 0 END) AS MissingBalance
FROM stg.trans;

SELECT
    SUM(CASE WHEN loan_id IS NULL THEN 1 ELSE 0 END) AS MissingLoanID,
    SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END) AS MissingAccountID,
    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END) AS MissingLoanDate,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS MissingAmount,
    SUM(CASE WHEN duration IS NULL THEN 1 ELSE 0 END) AS MissingDuration,
    SUM(CASE WHEN status IS NULL OR LTRIM(RTRIM(status)) = ''
             THEN 1 ELSE 0 END) AS MissingStatus
FROM stg.loan;
GO

/* 3. Invalid numeric values */
SELECT COUNT(*) AS InvalidTransactionAmounts
FROM stg.trans
WHERE amount < 0;

SELECT COUNT(*) AS InvalidLoanValues
FROM stg.loan
WHERE amount <= 0
   OR duration <= 0
   OR payments <= 0;
GO

/* 4. Values that require standardization */
SELECT frequency, COUNT(*) AS RecordCount
FROM stg.account
GROUP BY frequency
ORDER BY RecordCount DESC;

SELECT type, COUNT(*) AS RecordCount
FROM stg.trans
GROUP BY type
ORDER BY RecordCount DESC;

SELECT operation, COUNT(*) AS RecordCount
FROM stg.trans
GROUP BY operation
ORDER BY RecordCount DESC;

SELECT status, COUNT(*) AS RecordCount
FROM stg.loan
GROUP BY status
ORDER BY status;
GO