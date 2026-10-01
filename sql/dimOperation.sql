USE CzechBank_DW;
GO

SET NOCOUNT ON;
GO

/*==============================================================
  1. Remove DimOperation if it already exists

  Run this before creating FactTransaction foreign keys.
==============================================================*/

IF OBJECT_ID('dbo.DimOperation', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.DimOperation;
END;
GO

/*==============================================================
  2. Create DimOperation

  Grain:
      One row represents one transaction-operation code.
==============================================================*/

CREATE TABLE dbo.DimOperation
(
    OperationKey          INT IDENTITY(1,1) NOT NULL,
    OperationCode         NVARCHAR(50)      NOT NULL,
    OperationDescription  NVARCHAR(100)     NOT NULL,
    OperationGroup        NVARCHAR(50)      NOT NULL,

    CONSTRAINT PK_DimOperation
        PRIMARY KEY (OperationKey),

    CONSTRAINT UQ_DimOperation_OperationCode
        UNIQUE (OperationCode),

    CONSTRAINT CK_DimOperation_Group
        CHECK
        (
            OperationGroup IN
            (
                N'Cash Transaction',
                N'Card Transaction',
                N'Bank Transfer',
                N'Unknown'
            )
        )
);
GO

/*==============================================================
  3. Insert Unknown member

  OperationKey 0 is used when the source operation is
  missing or unrecognised.
==============================================================*/

SET IDENTITY_INSERT dbo.DimOperation ON;
GO

INSERT INTO dbo.DimOperation
(
    OperationKey,
    OperationCode,
    OperationDescription,
    OperationGroup
)
VALUES
(
    0,
    N'UNKNOWN',
    N'Unknown Operation',
    N'Unknown'
);
GO

SET IDENTITY_INSERT dbo.DimOperation OFF;
GO

/*==============================================================
  4. Prepare distinct source operation values

  Original operation codes:

      VYBER KARTOU    = Credit Card Withdrawal
      VKLAD           = Cash Deposit
      PREVOD Z UCTU   = Incoming Bank Transfer
      VYBER           = Cash Withdrawal
      PREVOD NA UCET  = Outgoing Bank Transfer
==============================================================*/

;WITH SourceOperations AS
(
    SELECT DISTINCT
        CASE
            WHEN t.operation IS NULL
              OR LTRIM(RTRIM(t.operation)) = N''
                THEN N'UNKNOWN'

            ELSE UPPER
                 (
                     LTRIM
                     (
                         RTRIM(t.operation)
                     )
                 )

        END AS OperationCode

    FROM CzechBank_DW.dbo.trans AS t
),

PreparedOperations AS
(
    SELECT
        so.OperationCode,

        /* English operation description */
        CASE so.OperationCode

            WHEN N'VYBER KARTOU'
                THEN N'Credit Card Withdrawal'

            WHEN N'VKLAD'
                THEN N'Cash Deposit'

            WHEN N'PREVOD Z UCTU'
                THEN N'Incoming Bank Transfer'

            WHEN N'VYBER'
                THEN N'Cash Withdrawal'

            WHEN N'PREVOD NA UCET'
                THEN N'Outgoing Bank Transfer'

            /* Support sources already translated into English */

            WHEN N'CREDIT CARD WITHDRAWAL'
                THEN N'Credit Card Withdrawal'

            WHEN N'CASH DEPOSIT'
                THEN N'Cash Deposit'

            WHEN N'COLLECTION FROM ANOTHER BANK'
                THEN N'Incoming Bank Transfer'

            WHEN N'INCOMING BANK TRANSFER'
                THEN N'Incoming Bank Transfer'

            WHEN N'CASH WITHDRAWAL'
                THEN N'Cash Withdrawal'

            WHEN N'REMITTANCE TO ANOTHER BANK'
                THEN N'Outgoing Bank Transfer'

            WHEN N'OUTGOING BANK TRANSFER'
                THEN N'Outgoing Bank Transfer'

            WHEN N'UNKNOWN'
                THEN N'Unknown Operation'

            ELSE N'Other Operation'

        END AS OperationDescription,

        /* Analytical operation group */
        CASE

            WHEN so.OperationCode IN
            (
                N'VYBER KARTOU',
                N'CREDIT CARD WITHDRAWAL'
            )
                THEN N'Card Transaction'

            WHEN so.OperationCode IN
            (
                N'VKLAD',
                N'VYBER',
                N'CASH DEPOSIT',
                N'CASH WITHDRAWAL'
            )
                THEN N'Cash Transaction'

            WHEN so.OperationCode IN
            (
                N'PREVOD Z UCTU',
                N'PREVOD NA UCET',
                N'COLLECTION FROM ANOTHER BANK',
                N'INCOMING BANK TRANSFER',
                N'REMITTANCE TO ANOTHER BANK',
                N'OUTGOING BANK TRANSFER'
            )
                THEN N'Bank Transfer'

            ELSE N'Unknown'

        END AS OperationGroup

    FROM SourceOperations AS so
)

/*==============================================================
  5. Load DimOperation

  The UNKNOWN operation was already inserted with key 0.
==============================================================*/

INSERT INTO dbo.DimOperation
(
    OperationCode,
    OperationDescription,
    OperationGroup
)
SELECT
    po.OperationCode,
    po.OperationDescription,
    po.OperationGroup

FROM PreparedOperations AS po

WHERE po.OperationCode <> N'UNKNOWN'

AND NOT EXISTS
(
    SELECT 1

    FROM dbo.DimOperation AS existing

    WHERE existing.OperationCode =
          po.OperationCode
);
GO

/*==============================================================
  6. Validate the loaded dimension
==============================================================*/

SELECT
    COUNT(*) AS TotalDimOperationRows,

    COUNT
    (
        DISTINCT OperationCode
    ) AS DistinctOperationCodes

FROM dbo.DimOperation;
GO

/*==============================================================
  7. Display all loaded operations
==============================================================*/

SELECT
    OperationKey,
    OperationCode,
    OperationDescription,
    OperationGroup

FROM dbo.DimOperation

ORDER BY OperationKey;
GO

/*==============================================================
  8. Compare source values with DimOperation mappings
==============================================================*/

SELECT
    COALESCE
    (
        NULLIF
        (
            UPPER
            (
                LTRIM
                (
                    RTRIM(t.operation)
                )
            ),
            N''
        ),
        N'UNKNOWN'
    ) AS SourceOperation,

    COALESCE
    (
        dop.OperationKey,
        0
    ) AS OperationKey,

    COALESCE
    (
        dop.OperationDescription,
        N'Unknown Operation'
    ) AS OperationDescription,

    COALESCE
    (
        dop.OperationGroup,
        N'Unknown'
    ) AS OperationGroup,

    COUNT(*) AS TransactionCount

FROM CzechBank_DW.dbo.trans AS t

LEFT JOIN dbo.DimOperation AS dop
    ON dop.OperationCode =
       COALESCE
       (
           NULLIF
           (
               UPPER
               (
                   LTRIM
                   (
                       RTRIM(t.operation)
                   )
               ),
               N''
           ),
           N'UNKNOWN'
       )

GROUP BY
    COALESCE
    (
        NULLIF
        (
            UPPER
            (
                LTRIM
                (
                    RTRIM(t.operation)
                )
            ),
            N''
        ),
        N'UNKNOWN'
    ),

    COALESCE
    (
        dop.OperationKey,
        0
    ),

    COALESCE
    (
        dop.OperationDescription,
        N'Unknown Operation'
    ),

    COALESCE
    (
        dop.OperationGroup,
        N'Unknown'
    )

ORDER BY SourceOperation;
GO

/*==============================================================
  9. Find source values that did not map
==============================================================*/

SELECT DISTINCT
    t.operation AS UnmappedOperation

FROM CzechBank_DW.dbo.trans AS t

LEFT JOIN dbo.DimOperation AS dop
    ON dop.OperationCode =
       COALESCE
       (
           NULLIF
           (
               UPPER
               (
                   LTRIM
                   (
                       RTRIM(t.operation)
                   )
               ),
               N''
           ),
           N'UNKNOWN'
       )

WHERE dop.OperationKey IS NULL;
GO