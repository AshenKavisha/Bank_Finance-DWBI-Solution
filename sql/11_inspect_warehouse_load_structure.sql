USE CzechBank_DW;
GO

select table_name,ordinal_position,column_name,data_type,character_maximum_length,numeric_precision,numeric_scale,is_nullable,columnproperty(
        OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME),
        COLUMN_NAME,
        'IsIdentity'
    ) AS IsIdentity
from INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN
  (
      'DimAccount',
      'DimClient',
      'DimDistrict',
      'DimDate',
      'DimLoanStatus',
      'DimTransactionType',
      'DimOperation',
      'FactLoan',
      'FactTransaction'
  )
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO

/* 2. Check current warehouse row counts */
SELECT 'DimAccount' AS TableName, COUNT_BIG(*) AS NumberOfRows
FROM dbo.DimAccount

UNION ALL
SELECT 'DimClient', COUNT_BIG(*) FROM dbo.DimClient

UNION ALL
SELECT 'DimDistrict', COUNT_BIG(*) FROM dbo.DimDistrict

UNION ALL
SELECT 'DimDate', COUNT_BIG(*) FROM dbo.DimDate

UNION ALL
SELECT 'DimLoanStatus', COUNT_BIG(*) FROM dbo.DimLoanStatus

UNION ALL
SELECT 'DimTransactionType', COUNT_BIG(*) FROM dbo.DimTransactionType

UNION ALL
SELECT 'DimOperation', COUNT_BIG(*) FROM dbo.DimOperation

UNION ALL
SELECT 'FactLoan', COUNT_BIG(*) FROM dbo.FactLoan

UNION ALL
SELECT 'FactTransaction', COUNT_BIG(*) FROM dbo.FactTransaction;
GO

/* 3. Inspect existing primary and unique keys */
SELECT
    t.name AS TableName,
    i.name AS IndexName,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique AS IsUnique,
    c.name AS ColumnName,
    ic.key_ordinal AS KeyPosition
FROM sys.tables AS t
INNER JOIN sys.indexes AS i
    ON t.object_id = i.object_id
INNER JOIN sys.index_columns AS ic
    ON i.object_id = ic.object_id
   AND i.index_id = ic.index_id
INNER JOIN sys.columns AS c
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
WHERE t.name IN
(
    'DimAccount',
    'DimClient',
    'DimDistrict',
    'DimDate',
    'DimLoanStatus',
    'DimTransactionType',
    'DimOperation',
    'FactLoan',
    'FactTransaction'
)
AND (i.is_primary_key = 1 OR i.is_unique = 1)
ORDER BY t.name, i.name, ic.key_ordinal;
GO

/* 4. Check cleaned staging counts */
SELECT 'account_clean' AS TableName, COUNT_BIG(*) AS NumberOfRows
FROM stg.account_clean

UNION ALL
SELECT 'client_clean', COUNT_BIG(*) FROM stg.client_clean

UNION ALL
SELECT 'district_clean', COUNT_BIG(*) FROM stg.district_clean

UNION ALL
SELECT 'loan_clean', COUNT_BIG(*) FROM stg.loan_clean

UNION ALL
SELECT 'transaction_clean', COUNT_BIG(*) FROM stg.transaction_clean;
GO


