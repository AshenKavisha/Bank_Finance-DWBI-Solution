USE CzechBank_DW;
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

/* Update existing current account records */
UPDATE target
SET
    target.AccountOpenDate = source.AccountOpenDateKey,
    target.StatementFrequency = source.StatementFrequency,
    target.AccountAgeGroup = source.AccountAgeGroup,
    target.SourceSystem = source.SourceSystem
FROM dbo.DimAccount AS target
INNER JOIN stg.account_clean AS source
    ON target.AccountID = source.AccountID
WHERE target.AccountID <> -1
  AND target.EffectiveTo = '9999-12-31';

DECLARE @UpdatedAccounts INT = @@ROWCOUNT;

/* Insert accounts that do not currently exist */
INSERT INTO dbo.DimAccount
(
    AccountID,
    AccountOpenDate,
    StatementFrequency,
    AccountAgeGroup,
    SourceSystem,
    EffectiveFrom,
    EffectiveTo
)
SELECT
    source.AccountID,
    source.AccountOpenDateKey,
    source.StatementFrequency,
    source.AccountAgeGroup,
    source.SourceSystem,
    source.AccountOpenDate,
    CAST('9999-12-31' AS DATE)
FROM stg.account_clean AS source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DimAccount AS target
    WHERE target.AccountID = source.AccountID
      AND target.EffectiveTo = '9999-12-31'
);

DECLARE @InsertedAccounts INT = @@ROWCOUNT;

COMMIT TRANSACTION;

/* Display loading results */
SELECT
    @UpdatedAccounts AS UpdatedAccounts,
    @InsertedAccounts AS InsertedAccounts;
GO

/* Validate DimAccount loading */

SELECT
    COUNT(*) AS TotalAccountRows,
    SUM(CASE WHEN AccountID = -1 THEN 1 ELSE 0 END)
        AS UnknownRows,
    SUM(CASE WHEN AccountID <> -1 THEN 1 ELSE 0 END)
        AS BusinessAccountRows
FROM dbo.DimAccount;
GO

/* Check that every cleaned account has a current dimension record */
SELECT COUNT(*) AS MissingAccountsAfterLoad
FROM stg.account_clean AS source
LEFT JOIN dbo.DimAccount AS target
    ON source.AccountID = target.AccountID
   AND target.EffectiveTo = '9999-12-31'
WHERE target.AccountKey IS NULL;
GO

/* Check duplicate current account records */
SELECT
    AccountID,
    COUNT(*) AS CurrentRecordCount
FROM dbo.DimAccount
WHERE EffectiveTo = '9999-12-31'
  AND AccountID <> -1
GROUP BY AccountID
HAVING COUNT(*) > 1;
GO

SELECT TOP 10
    AccountKey,
    AccountID,
    AccountOpenDate,
    StatementFrequency,
    AccountAgeGroup,
    SourceSystem,
    EffectiveFrom,
    EffectiveTo
FROM dbo.DimAccount
ORDER BY AccountID;
GO