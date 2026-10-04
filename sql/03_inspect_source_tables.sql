USE CzechBank_DW;
GO

-- =====================================================
-- 1. Source table columns
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
    'account',
    'client',
    'disp',
    'district',
    'loan',
    'order',
    'trans',
    'card'
)
ORDER BY TABLE_NAME, ORDINAL_POSITION;
GO

-- =====================================================
-- 2. Source table row counts
-- =====================================================

SELECT 'account' AS TableName, COUNT(*) AS NumberOfRows
FROM dbo.account

UNION ALL

SELECT 'client', COUNT(*)
FROM dbo.client

UNION ALL

SELECT 'disp', COUNT(*)
FROM dbo.disp

UNION ALL

SELECT 'district', COUNT(*)
FROM dbo.district

UNION ALL

SELECT 'loan', COUNT(*)
FROM dbo.loan

UNION ALL

SELECT 'order', COUNT(*)
FROM dbo.[order]

UNION ALL

SELECT 'trans', COUNT(*)
FROM dbo.trans

UNION ALL

SELECT 'card', COUNT(*)
FROM dbo.card;
GO

-- =====================================================
-- 3. Sample source data
-- =====================================================

SELECT TOP 5 * FROM dbo.account;
SELECT TOP 5 * FROM dbo.client;
SELECT TOP 5 * FROM dbo.disp;
SELECT TOP 5 * FROM dbo.district;
SELECT TOP 5 * FROM dbo.loan;
SELECT TOP 5 * FROM dbo.[order];
SELECT TOP 5 * FROM dbo.trans;
SELECT TOP 5 * FROM dbo.card;
GO