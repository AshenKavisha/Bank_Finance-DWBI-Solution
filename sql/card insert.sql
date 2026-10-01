USE CzechBank_OLTP;
GO

/* 1. Create the card table */
IF OBJECT_ID('dbo.card', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.card
    (
        card_id     INT          NOT NULL,
        disp_id     INT          NOT NULL,
        card_type   NVARCHAR(50) NULL,
        issued      DATETIME2(0) NULL,

        CONSTRAINT PK_card PRIMARY KEY (card_id)
    );
END;
GO

/* 2. Read card.json */
DECLARE @json NVARCHAR(MAX);

SELECT @json = BulkColumn
FROM OPENROWSET
(
    BULK 'D:\BankData\card.json',
    SINGLE_CLOB
) AS JsonFile;

/*
If card.json contains only one object instead of an array,
convert the object into an array.
*/
IF LEFT(LTRIM(@json), 1) = '{'
BEGIN
    SET @json = N'[' + @json + N']';
END;

/* 3. Insert JSON data */
INSERT INTO dbo.card
(
    card_id,
    disp_id,
    card_type,
    issued
)
SELECT
    J.card_id,
    J.disp_id,
    J.card_type,

    /* Convert 931107 00:00:00 into 1993-11-07 00:00:00 */
    TRY_CONVERT
    (
        DATETIME2(0),
        CONCAT
        (
            '19',
            SUBSTRING(J.issued_text, 1, 2), '-',
            SUBSTRING(J.issued_text, 3, 2), '-',
            SUBSTRING(J.issued_text, 5, 2),
            SUBSTRING(J.issued_text, 7, 9)
        ),
        120
    ) AS issued
FROM OPENJSON(@json)
WITH
(
    card_id       INT           '$.card_id',
    disp_id       INT           '$.disp_id',
    card_type     NVARCHAR(50)  '$.type',
    issued_text   NVARCHAR(30)  '$.issued'
) AS J
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.card AS C
    WHERE C.card_id = J.card_id
);
GO

/* 4. Check the loaded data */
SELECT
    card_id,
    disp_id,
    card_type,
    issued
FROM dbo.card
ORDER BY card_id;
GO