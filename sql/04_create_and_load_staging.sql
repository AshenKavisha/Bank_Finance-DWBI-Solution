USE CzechBank_DW;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Create staging schema if it does not exist
    IF NOT EXISTS (
        SELECT 1
        FROM sys.schemas
        WHERE name = 'stg'
    )
    BEGIN
        EXEC('CREATE SCHEMA stg');
    END;

    -- Remove previous staging tables to make this script repeatable
    DROP TABLE IF EXISTS stg.card;
    DROP TABLE IF EXISTS stg.trans;
    DROP TABLE IF EXISTS stg.[order];
    DROP TABLE IF EXISTS stg.loan;
    DROP TABLE IF EXISTS stg.district;
    DROP TABLE IF EXISTS stg.disp;
    DROP TABLE IF EXISTS stg.client;
    DROP TABLE IF EXISTS stg.account;

    -- Extract complete source tables into staging
    SELECT *
    INTO stg.account
    FROM dbo.account;

    SELECT *
    INTO stg.client
    FROM dbo.client;

    SELECT *
    INTO stg.disp
    FROM dbo.disp;

    SELECT *
    INTO stg.district
    FROM dbo.district;

    SELECT *
    INTO stg.loan
    FROM dbo.loan;

    SELECT *
    INTO stg.[order]
    FROM dbo.[order];

    SELECT *
    INTO stg.trans
    FROM dbo.trans;

    SELECT *
    INTO stg.card
    FROM dbo.card;

    -- Add audit timestamps
    ALTER TABLE stg.account
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_account_load
        DEFAULT SYSDATETIME() WITH VALUES;

    ALTER TABLE stg.client
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_client_load
        DEFAULT SYSDATETIME() WITH VALUES;

    ALTER TABLE stg.disp
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_disp_load
        DEFAULT SYSDATETIME() WITH VALUES;

    ALTER TABLE stg.district
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_district_load
        DEFAULT SYSDATETIME() WITH VALUES;

    ALTER TABLE stg.loan
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_loan_load
        DEFAULT SYSDATETIME() WITH VALUES;

    ALTER TABLE stg.[order]
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_order_load
        DEFAULT SYSDATETIME() WITH VALUES;

    ALTER TABLE stg.trans
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_trans_load
        DEFAULT SYSDATETIME() WITH VALUES;

    ALTER TABLE stg.card
        ADD ETL_LoadDateTime DATETIME2 NOT NULL
        CONSTRAINT DF_stg_card_load
        DEFAULT SYSDATETIME() WITH VALUES;

    COMMIT TRANSACTION;

    PRINT 'Staging extraction completed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Validate staging row counts
SELECT 'account' AS TableName, COUNT(*) AS StagingRows
FROM stg.account

UNION ALL SELECT 'client', COUNT(*) FROM stg.client
UNION ALL SELECT 'disp', COUNT(*) FROM stg.disp
UNION ALL SELECT 'district', COUNT(*) FROM stg.district
UNION ALL SELECT 'loan', COUNT(*) FROM stg.loan
UNION ALL SELECT 'order', COUNT(*) FROM stg.[order]
UNION ALL SELECT 'trans', COUNT(*) FROM stg.trans
UNION ALL SELECT 'card', COUNT(*) FROM stg.card;
GO