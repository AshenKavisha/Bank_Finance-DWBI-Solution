

SET LANGUAGE English;
SET DATEFIRST 1;

/* Remove the existing incorrect row */
DELETE FROM dbo.DimDate;

/* Set the calendar range.
   Change these dates if your source range is different. */
DECLARE @StartDate DATE = '1900-01-01';
DECLARE @EndDate   DATE = '1998-12-31';

/* DateSeries and INSERT must execute as one statement */
;WITH DateSeries AS
(
    SELECT @StartDate AS FullDate

    UNION ALL

    SELECT DATEADD(DAY, 1, FullDate)
    FROM DateSeries
    WHERE FullDate < @EndDate
)
INSERT INTO dbo.DimDate
(
    DateKey,
    FullDate,
    DayNumber,
    DayName,
    WeekNumber,
    MonthNumber,
    MonthName,
    Quarter,
    [Year],
    YearMonth
)
SELECT
    CONVERT
    (
        INT,
        CONVERT(CHAR(8), FullDate, 112)
    ) AS DateKey,

    FullDate,

    DAY(FullDate) AS DayNumber,

    DATENAME
    (
        WEEKDAY,
        FullDate
    ) AS DayName,

    DATEPART
    (
        ISO_WEEK,
        FullDate
    ) AS WeekNumber,

    MONTH(FullDate) AS MonthNumber,

    DATENAME
    (
        MONTH,
        FullDate
    ) AS MonthName,

    DATEPART
    (
        QUARTER,
        FullDate
    ) AS Quarter,

    YEAR(FullDate) AS [Year],

    RIGHT
    (
        '0' + CONVERT(VARCHAR(2), MONTH(FullDate)),
        2
    ) AS YearMonth

FROM DateSeries

OPTION (MAXRECURSION 0);
GO