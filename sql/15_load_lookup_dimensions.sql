USE CzechBank_DW;
GO

SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

/* =========================================================
   1. Load loan-status mappings
   ========================================================= */

WITH LoanStatusSource AS
(
    SELECT *
    FROM (VALUES
        ('UNKNOWN', 'Unknown Loan Status', 'Unknown', 0),
        ('A', 'Completed Without Repayment Problems', 'Completed', 0),
        ('B', 'Completed With Repayment Problems', 'Completed', 1),
        ('C', 'Active Without Current Repayment Problems', 'Active', 0),
        ('D', 'Active With Current Debt', 'Active', 1)
    ) AS valueset
    (
        LoanStatusCode,
        LoanStatusDescription,
        LoanStatusGroup,
        ProblemFlag
    )
)
UPDATE target
SET
    target.LoanStatusDescription = source.LoanStatusDescription,
    target.LoanStatusGroup = source.LoanStatusGroup,
    target.ProblemFlag = source.ProblemFlag
FROM dbo.DimLoanStatus AS target
INNER JOIN LoanStatusSource AS source
    ON target.LoanStatusCode = source.LoanStatusCode;

WITH LoanStatusSource AS
(
    SELECT *
    FROM (VALUES
        ('UNKNOWN', 'Unknown Loan Status', 'Unknown', 0),
        ('A', 'Completed Without Repayment Problems', 'Completed', 0),
        ('B', 'Completed With Repayment Problems', 'Completed', 1),
        ('C', 'Active Without Current Repayment Problems', 'Active', 0),
        ('D', 'Active With Current Debt', 'Active', 1)
    ) AS valueset
    (
        LoanStatusCode,
        LoanStatusDescription,
        LoanStatusGroup,
        IsProblemStatus
    )
)
INSERT INTO dbo.DimLoanStatus
(
    LoanStatusCode,
    LoanStatusDescription,
    LoanStatusGroup,
    ProblemFlag
)
SELECT
    source.LoanStatusCode,
    source.LoanStatusDescription,
    source.LoanStatusGroup,
    source.IsProblemStatus
FROM LoanStatusSource AS source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DimLoanStatus AS target
    WHERE target.LoanStatusCode = source.LoanStatusCode
);

/* =========================================================
   2. Load transaction-type mappings
   ========================================================= */

WITH TransactionTypeSource AS
(
    SELECT *
    FROM (VALUES
        ('UNKNOWN', 'Unknown Transaction Type', 'Unknown'),
        ('PRIJEM', 'Credit', 'Incoming'),
        ('VYBER', 'Withdrawal', 'Outgoing'),
        ('VYDAJ', 'Debit', 'Outgoing')
    ) AS valueset
    (
        TransactionTypeCode,
        TransactionTypeName,
        CashFlowDirection
    )
)
UPDATE target
SET
    target.TransactionTypeName = source.TransactionTypeName,
    target.CashFlowDirection = source.CashFlowDirection
FROM dbo.DimTransactionType AS target
INNER JOIN TransactionTypeSource AS source
    ON target.TransactionTypeCode = source.TransactionTypeCode;

WITH TransactionTypeSource AS
(
    SELECT *
    FROM (VALUES
        ('UNKNOWN', 'Unknown Transaction Type', 'Unknown'),
        ('PRIJEM', 'Credit', 'Incoming'),
        ('VYBER', 'Withdrawal', 'Outgoing'),
        ('VYDAJ', 'Debit', 'Outgoing')
    ) AS valueset
    (
        TransactionTypeCode,
        TransactionTypeName,
        CashFlowDirection
    )
)
INSERT INTO dbo.DimTransactionType
(
    TransactionTypeCode,
    TransactionTypeName,
    CashFlowDirection
)
SELECT
    source.TransactionTypeCode,
    source.TransactionTypeName,
    source.CashFlowDirection
FROM TransactionTypeSource AS source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DimTransactionType AS target
    WHERE target.TransactionTypeCode = source.TransactionTypeCode
);

/* =========================================================
   3. Load operation mappings
   ========================================================= */

WITH OperationSource AS
(
    SELECT *
    FROM (VALUES
        ('UNKNOWN', 'Unknown Operation', 'Unknown'),
        ('PREVOD NA UCET', 'Outgoing Bank Transfer', 'Bank Transfer'),
        ('PREVOD Z UCTU', 'Incoming Bank Transfer', 'Bank Transfer'),
        ('VKLAD', 'Cash Deposit', 'Cash Transaction'),
        ('VYBER', 'Cash Withdrawal', 'Cash Transaction'),
        ('VYBER KARTOU', 'Credit Card Withdrawal', 'Card Transaction')
    ) AS valueset
    (
        OperationCode,
        OperationDescription,
        OperationGroup
    )
)
UPDATE target
SET
    target.OperationDescription = source.OperationDescription,
    target.OperationGroup = source.OperationGroup
FROM dbo.DimOperation AS target
INNER JOIN OperationSource AS source
    ON target.OperationCode = source.OperationCode;

WITH OperationSource AS
(
    SELECT *
    FROM (VALUES
        ('UNKNOWN', 'Unknown Operation', 'Unknown'),
        ('PREVOD NA UCET', 'Outgoing Bank Transfer', 'Bank Transfer'),
        ('PREVOD Z UCTU', 'Incoming Bank Transfer', 'Bank Transfer'),
        ('VKLAD', 'Cash Deposit', 'Cash Transaction'),
        ('VYBER', 'Cash Withdrawal', 'Cash Transaction'),
        ('VYBER KARTOU', 'Credit Card Withdrawal', 'Card Transaction')
    ) AS valueset
    (
        OperationCode,
        OperationDescription,
        OperationGroup
    )
)
INSERT INTO dbo.DimOperation
(
    OperationCode,
    OperationDescription,
    OperationGroup
)
SELECT
    source.OperationCode,
    source.OperationDescription,
    source.OperationGroup
FROM OperationSource AS source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DimOperation AS target
    WHERE target.OperationCode = source.OperationCode
);

COMMIT TRANSACTION;
GO


---- VALIDATION 

SELECT 'DimLoanStatus' AS TableName, COUNT(*) AS NumberOfRows
FROM dbo.DimLoanStatus

UNION ALL
SELECT 'DimTransactionType', COUNT(*)
FROM dbo.DimTransactionType

UNION ALL
SELECT 'DimOperation', COUNT(*)
FROM dbo.DimOperation;
GO

SELECT * FROM dbo.DimLoanStatus ORDER BY LoanStatusKey;
SELECT * FROM dbo.DimTransactionType ORDER BY TransactionTypeKey;
SELECT * FROM dbo.DimOperation ORDER BY OperationKey;
GO