USE CzechBank_DW;
GO

-- Display all tables in the restored database
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO

-- Display row counts for every table
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
JOIN sys.partitions p
    ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
GO

-- Examine important warehouse tables
EXEC sp_help 'dbo.DimAccount';
EXEC sp_help 'dbo.DimClient';
EXEC sp_help 'dbo.DimDate';
EXEC sp_help 'dbo.DimDistrict';
EXEC sp_help 'dbo.FactTransaction';
EXEC sp_help 'dbo.FactLoan';
GO  .