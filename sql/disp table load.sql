USE CzechBank_DW;
GO

-- Clean up a temporary table from an earlier failed attempt
DROP TABLE IF EXISTS dbo.disp_new;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    ------------------------------------------------------------
    -- 1. Validate existing disp_id values
    ------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM dbo.disp
        WHERE disp_id IS NULL
    )
    BEGIN
        THROW 50001,
              'disp_id contains NULL values. Primary key cannot be created.',
              1;
    END;

    IF EXISTS
    (
        SELECT disp_id
        FROM dbo.disp
        GROUP BY disp_id
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50002,
              'disp_id contains duplicate values. Primary key cannot be created.',
              1;
    END;

    ------------------------------------------------------------
    -- 2. Create replacement table without PK initially
    ------------------------------------------------------------

    CREATE TABLE dbo.disp_new
    (
        disp_id INT IDENTITY(1,1) NOT NULL,
        client_id INT NOT NULL,
        account_id INT NOT NULL,
        [type] NVARCHAR(50) NOT NULL
    );

    ------------------------------------------------------------
    -- 3. Preserve existing disp_id values
    ------------------------------------------------------------

    SET IDENTITY_INSERT dbo.disp_new ON;

    INSERT INTO dbo.disp_new
    (
        disp_id,
        client_id,
        account_id,
        [type]
    )
    SELECT
        disp_id,
        client_id,
        account_id,
        [type]
    FROM dbo.disp;

    SET IDENTITY_INSERT dbo.disp_new OFF;

    ------------------------------------------------------------
    -- 4. Verify that all rows were copied
    ------------------------------------------------------------

    IF
    (
        SELECT COUNT_BIG(*)
        FROM dbo.disp_new
    )
    <>
    (
        SELECT COUNT_BIG(*)
        FROM dbo.disp
    )
    BEGIN
        THROW 50003,
              'Row counts do not match. The operation was cancelled.',
              1;
    END;

    ------------------------------------------------------------
    -- 5. Remove original table
    ------------------------------------------------------------

    DROP TABLE dbo.disp;

    ------------------------------------------------------------
    -- 6. Rename replacement table
    ------------------------------------------------------------

    EXEC sys.sp_rename
        @objname = N'dbo.disp_new',
        @newname = N'disp',
        @objtype = N'OBJECT';

    ------------------------------------------------------------
    -- 7. Create primary key after old PK has been removed
    ------------------------------------------------------------

    ALTER TABLE dbo.disp
    ADD CONSTRAINT PK_disp
        PRIMARY KEY (disp_id);

    COMMIT TRANSACTION;

    PRINT 'disp_id successfully changed to IDENTITY(1,1) PRIMARY KEY.';
END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    BEGIN TRY
        SET IDENTITY_INSERT dbo.disp_new OFF;
    END TRY
    BEGIN CATCH
        -- Ignore because IDENTITY_INSERT might already be OFF
    END CATCH;

    SELECT
        ERROR_NUMBER() AS error_number,
        ERROR_LINE() AS error_line,
        ERROR_MESSAGE() AS error_message;
END CATCH;
GO
