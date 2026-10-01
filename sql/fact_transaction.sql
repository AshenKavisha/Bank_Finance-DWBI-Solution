USE CzechBank_DW;
GO

SET NOCOUNT ON;
GO

/*==============================================================
  Restore AccountKey = 0
==============================================================*/

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DimAccount
    WHERE AccountKey = 0
)
BEGIN
    SET IDENTITY_INSERT dbo.DimAccount ON;

    INSERT INTO dbo.DimAccount
    (
        AccountKey,
        AccountID,
        AccountOpenDate,
        StatementFrequency,
        AccountAgeGroup,
        SourceSystem,
        EffectiveFrom,
        EffectiveTo,
        IsCurrent
    )
    VALUES
    (
        0,
        -1,
        19000101,
        N'Unknown',
        N'Unknown',
        N'Unknown',
        '1900-01-01',
        '9999-12-31',
        1
    );

    SET IDENTITY_INSERT dbo.DimAccount OFF;
END;
GO

/*==============================================================
  Restore DistrictKey = 0
==============================================================*/

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DimDistrict
    WHERE DistrictKey = 0
)
BEGIN
    SET IDENTITY_INSERT dbo.DimDistrict ON;

    INSERT INTO dbo.DimDistrict
    (
        DistrictKey,
        DistrictID,
        DistrictName,
        RegionName,
        Population,
        AverageSalary,
        UnemploymentMeasure,
        EntrepreneurMeasure,
        CrimeMeasure
    )
    VALUES
    (
        0,
        -1,
        N'Unknown',
        N'Unknown',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
    );

    SET IDENTITY_INSERT dbo.DimDistrict OFF;
END;
GO

/*==============================================================
  Restore TransactionTypeKey = 0
==============================================================*/

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DimTransactionType
    WHERE TransactionTypeKey = 0
)
BEGIN
    SET IDENTITY_INSERT dbo.DimTransactionType ON;

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

    SET IDENTITY_INSERT dbo.DimTransactionType OFF;
END;
GO

/*==============================================================
  Restore OperationKey = 0
==============================================================*/

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.DimOperation
    WHERE OperationKey = 0
)
BEGIN
    SET IDENTITY_INSERT dbo.DimOperation ON;

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

    SET IDENTITY_INSERT dbo.DimOperation OFF;
END;
GO