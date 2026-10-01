USE lpetrocelli_czech_financial;
GO

CREATE TABLE dbo.card
(
    card_id int,
    disp_id int,
    type nvarchar(50)
);
GO

DECLARE @json nvarchar(max);

SELECT @json = BulkColumn
FROM OPENROWSET
(
    BULK 'D:\BankData\card.json',
    SINGLE_CLOB
) AS json_file;

INSERT INTO dbo.card
(
    card_id,
    disp_id,
    type
)
SELECT
    card_id,
    disp_id,
    type
FROM OPENJSON(@json)
WITH
(
    card_id int '$.card_id',
    disp_id int '$.disp_id',
    type nvarchar(50) '$.type'
);
GO

SELECT  *
FROM dbo.card;