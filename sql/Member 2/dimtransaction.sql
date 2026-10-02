USE CzechBank_DW;
GO

SET NOCOUNT ON;
GO

/*==============================================================
  1. Remove DimTransactionType if it already exists

  Run this before creating FactTransaction foreign keys.
==============================================================*/

IF OBJECT_ID('dbo.DimTransactionType', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.DimTransactionType;
END;
GO

/*==============================================================
  2. Create DimTransactionType

  Grain:
      One row represents one transaction-type code.
==============================================================*/

CREATE TABLE dbo.DimTransactionType
(
    TransactionTypeKey   INT IDENTITY(1,1) NOT NULL,
    TransactionTypeCode  NVARCHAR(30)      NOT NULL,
    TransactionTypeName  NVARCHAR(50)      NOT NULL,
    CashFlowDirection    NVARCHAR(20)      NOT NULL,

    CONSTRAINT PK_DimTransactionType
        PRIMARY KEY (TransactionTypeKey),

    CONSTRAINT UQ_DimTransactionType_Code
        UNIQUE (TransactionTypeCode),

    CONSTRAINT CK_DimTransactionType_Direction
        CHECK
        (
            CashFlowDirection IN
            (
                N'Incoming',
                N'Outgoing',
                N'Unknown'
            )
        )
);
GO

/*==============================================================
  3. Insert Unknown member

  TransactionTypeKey 0 will be used when a transaction
  has a missing or unrecognised type.
==============================================================*/

SET IDENTITY_INSERT dbo.DimTransactionType ON;
GO

INSERT INTO dbo.DimTransactionType
(
    TransactionTypeKey,
    TransactionTypeCode,
    TransactionTypeName,
    CashFlowDirection
)
VALUES
(
    0,
    N'UNKNOWN',
    N'Unknown Transaction Type',
    N'Unknown'
);
GO

SET IDENTITY_INSERT dbo.DimTransactionType OFF;
GO

/*==============================================================
  4. Prepare distinct transaction types from the source

  Supported original codes:
      PRIJEM = incoming credit
      VYDAJ  = outgoing debit
      VYBER  = outgoing withdrawal

  The query also supports source values already translated
  into English.
==============================================================*/

;WITH SourceTransactionTypes AS
(
    SELECT DISTINCT
        CASE
            WHEN t.[type] IS NULL
              OR LTRIM(RTRIM(t.[type])) = N''
                THEN N'UNKNOWN'

            ELSE UPPER
                 (
                     LTRIM
                     (
                         RTRIM(t.[type])
                     )
                 )
        END AS TransactionTypeCode

    FROM CzechBank_DW.dbo.trans AS t
),

PreparedTransactionTypes AS
(
    SELECT
        stt.TransactionTypeCode,

        CASE stt.TransactionTypeCode
            WHEN N'PRIJEM'
                THEN N'Credit'

            WHEN N'VYDAJ'
                THEN N'Debit'

            WHEN N'VYBER'
                THEN N'Withdrawal'

            WHEN N'CREDIT'
                THEN N'Credit'

            WHEN N'DEBIT'
                THEN N'Debit'

            WHEN N'WITHDRAWAL'
                THEN N'Withdrawal'

            WHEN N'UNKNOWN'
                THEN N'Unknown Transaction Type'

            ELSE N'Other Transaction Type'
        END AS TransactionTypeName,

        CASE
            WHEN stt.TransactionTypeCode IN
                 (
                     N'PRIJEM',
                     N'CREDIT',
                     N'INCOMING'
                 )
                THEN N'Incoming'

            WHEN stt.TransactionTypeCode IN
                 (
                     N'VYDAJ',
                     N'VYBER',
                     N'DEBIT',
                     N'WITHDRAWAL',
                     N'OUTGOING'
                 )
                THEN N'Outgoing'

            ELSE N'Unknown'
        END AS CashFlowDirection

    FROM SourceTransactionTypes AS stt
)

/*==============================================================
  5. Load DimTransactionType

  UNKNOWN is not inserted again because key 0 already
  represents the unknown member.
==============================================================*/

INSERT INTO dbo.DimTransactionType
(
    TransactionTypeCode,
    TransactionTypeName,
    CashFlowDirection
)
SELECT
    ptt.TransactionTypeCode,
    ptt.TransactionTypeName,
    ptt.CashFlowDirection

FROM PreparedTransactionTypes AS ptt

WHERE ptt.TransactionTypeCode <> N'UNKNOWN'

AND NOT EXISTS
(
    SELECT 1

    FROM dbo.DimTransactionType AS existing

    WHERE existing.TransactionTypeCode =
          ptt.TransactionTypeCode
);
GO

/*==============================================================
  6. Validate the loaded dimension
==============================================================*/

SELECT
    COUNT(*) AS TotalTransactionTypeRows,
    COUNT(DISTINCT TransactionTypeCode)
        AS DistinctTransactionTypeCodes

FROM dbo.DimTransactionType;
GO

/*==============================================================
  7. Display all loaded transaction types
==============================================================*/

SELECT
    TransactionTypeKey,
    TransactionTypeCode,
    TransactionTypeName,
    CashFlowDirection

FROM dbo.DimTransactionType

ORDER BY TransactionTypeKey;
GO

/*==============================================================
  8. Compare source values with translated dimension values
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
                    RTRIM(t.[type])
                )
            ),
            N''
        ),
        N'UNKNOWN'
    ) AS SourceTransactionType,

    dtt.TransactionTypeKey,
    dtt.TransactionTypeName,
    dtt.CashFlowDirection,

    COUNT(*) AS TransactionCount

FROM CzechBank_DW.dbo.trans AS t

LEFT JOIN dbo.DimTransactionType AS dtt
    ON dtt.TransactionTypeCode =
       COALESCE
       (
           NULLIF
           (
               UPPER
               (
                   LTRIM
                   (
                       RTRIM(t.[type])
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
                    RTRIM(t.[type])
                )
            ),
            N''
        ),
        N'UNKNOWN'
    ),

    dtt.TransactionTypeKey,
    dtt.TransactionTypeName,
    dtt.CashFlowDirection

ORDER BY SourceTransactionType;
GO

/*==============================================================
  9. Find any source values that did not map
==============================================================*/

SELECT DISTINCT
    t.[type] AS UnmappedTransactionType

FROM CzechBank_DW.dbo.trans AS t

LEFT JOIN dbo.DimTransactionType AS dtt
    ON dtt.TransactionTypeCode =
       COALESCE
       (
           NULLIF
           (
               UPPER
               (
                   LTRIM
                   (
                       RTRIM(t.[type])
                   )
               ),
               N''
           ),
           N'UNKNOWN'
       )

WHERE dtt.TransactionTypeKey IS NULL;
GO