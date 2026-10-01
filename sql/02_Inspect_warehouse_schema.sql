USE CzechBank_DW;
GO

-- =====================================================
-- 1. Display columns in dimensions and fact tables
-- =====================================================

SELECT
    TABLE_NAME,
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN (
    'DimAccount',
    'DimClient',
    'DimDate',
    'DimDistrict',
    'DimLoanStatus',
    'DimOperation',
    'DimTransactionType',
    'FactLoan',
    'FactTransaction'
)
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO

-- =====================================================
-- 2. Display primary keys
-- =====================================================

SELECT
    tc.TABLE_NAME,
    kcu.COLUMN_NAME,
    tc.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
  AND tc.TABLE_NAME IN (
      'DimAccount',
      'DimClient',
      'DimDate',
      'DimDistrict',
      'DimLoanStatus',
      'DimOperation',
      'DimTransactionType',
      'FactLoan',
      'FactTransaction'
  )
ORDER BY tc.TABLE_NAME, kcu.ORDINAL_POSITION;
GO

-- =====================================================
-- 3. Display foreign-key relationships
-- =====================================================

SELECT
    OBJECT_NAME(fkc.parent_object_id) AS ChildTable,
    COL_NAME(
        fkc.parent_object_id,
        fkc.parent_column_id
    ) AS ChildColumn,
    OBJECT_NAME(fkc.referenced_object_id) AS ParentTable,
    COL_NAME(
        fkc.referenced_object_id,
        fkc.referenced_column_id
    ) AS ParentColumn,
    fk.name AS ForeignKeyName
FROM sys.foreign_key_columns fkc
JOIN sys.foreign_keys fk
    ON fkc.constraint_object_id = fk.object_id
ORDER BY ChildTable, ForeignKeyName;
GO

-- =====================================================
-- 4. Display sample dimension records
-- =====================================================

SELECT TOP 5 * FROM dbo.DimAccount;
SELECT TOP 5 * FROM dbo.DimClient;
SELECT TOP 5 * FROM dbo.DimDate;
SELECT TOP 5 * FROM dbo.DimDistrict;
SELECT TOP 5 * FROM dbo.DimLoanStatus;
SELECT TOP 5 * FROM dbo.DimOperation;
SELECT TOP 5 * FROM dbo.DimTransactionType;
GO

-- =====================================================
-- 5. Display sample fact records
-- =====================================================

SELECT TOP 5 * FROM dbo.FactLoan;
SELECT TOP 5 * FROM dbo.FactTransaction;
GO