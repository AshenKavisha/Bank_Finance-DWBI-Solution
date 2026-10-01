USE CzechBank_DW;
GO

SET NOCOUNT ON;
GO

/*==============================================================
  1. Remove DimLoanStatus if it already exists

  Run this before creating FactLoan foreign keys.
==============================================================*/

IF OBJECT_ID('dbo.DimLoanStatus', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.DimLoanStatus;
END;
GO

/*==============================================================
  2. Create DimLoanStatus

  Grain:
      One row represents one loan-status code.
==============================================================*/

CREATE TABLE dbo.DimLoanStatus
(
    LoanStatusKey          INT IDENTITY(1,1) NOT NULL,
    LoanStatusCode         NVARCHAR(10)      NOT NULL,
    LoanStatusDescription  NVARCHAR(100)     NOT NULL,
    LoanStatusGroup        NVARCHAR(30)      NOT NULL,
    ProblemFlag            BIT               NOT NULL,

    CONSTRAINT PK_DimLoanStatus
        PRIMARY KEY (LoanStatusKey),

    CONSTRAINT UQ_DimLoanStatus_Code
        UNIQUE (LoanStatusCode),

    CONSTRAINT CK_DimLoanStatus_Group
        CHECK
        (
            LoanStatusGroup IN
            (
                N'Completed',
                N'Active',
                N'Unknown'
            )
        ),

    CONSTRAINT CK_DimLoanStatus_ProblemFlag
        CHECK
        (
            ProblemFlag IN (0, 1)
        )
);
GO

/*==============================================================
  3. Insert Unknown member

  LoanStatusKey 0 is used when a loan status is missing
  or does not match a known status.
==============================================================*/

SET IDENTITY_INSERT dbo.DimLoanStatus ON;
GO

INSERT INTO dbo.DimLoanStatus
(
    LoanStatusKey,
    LoanStatusCode,
    LoanStatusDescription,
    LoanStatusGroup,
    ProblemFlag
)
VALUES
(
    0,
    N'UNKNOWN',
    N'Unknown Loan Status',
    N'Unknown',
    0
);
GO

SET IDENTITY_INSERT dbo.DimLoanStatus OFF;
GO

/*==============================================================
  4. Prepare distinct source loan-status values

  Status definitions:

      A = Completed without repayment problems
      B = Completed but not fully repaid
      C = Active without current repayment problems
      D = Active with current debt
==============================================================*/

;WITH SourceLoanStatuses AS
(
    SELECT DISTINCT
        CASE
            WHEN l.[status] IS NULL
              OR LTRIM(RTRIM(l.[status])) = N''
            THEN N'UNKNOWN'

            ELSE UPPER
                 (
                     LTRIM
                     (
                         RTRIM(l.[status])
                     )
                 )
        END AS LoanStatusCode

    FROM CzechBank_DW.dbo.loan AS l
),

PreparedLoanStatuses AS
(
    SELECT
        sls.LoanStatusCode,

        /* English description */
        CASE sls.LoanStatusCode

            WHEN N'A'
            THEN N'Completed Without Repayment Problems'

            WHEN N'B'
            THEN N'Completed With Repayment Problems'

            WHEN N'C'
            THEN N'Active Without Current Repayment Problems'

            WHEN N'D'
            THEN N'Active With Current Debt'

            WHEN N'UNKNOWN'
            THEN N'Unknown Loan Status'

            ELSE N'Other Loan Status'

        END AS LoanStatusDescription,

        /* Contract stage */
        CASE
            WHEN sls.LoanStatusCode IN
                 (
                     N'A',
                     N'B'
                 )
            THEN N'Completed'

            WHEN sls.LoanStatusCode IN
                 (
                     N'C',
                     N'D'
                 )
            THEN N'Active'

            ELSE N'Unknown'

        END AS LoanStatusGroup,

        /* Repayment-problem indicator */
        CASE
            WHEN sls.LoanStatusCode IN
                 (
                     N'B',
                     N'D'
                 )
            THEN CAST(1 AS BIT)

            ELSE CAST(0 AS BIT)

        END AS ProblemFlag

    FROM SourceLoanStatuses AS sls
)

/*==============================================================
  5. Load DimLoanStatus

  UNKNOWN is excluded because key 0 was already inserted.
==============================================================*/

INSERT INTO dbo.DimLoanStatus
(
    LoanStatusCode,
    LoanStatusDescription,
    LoanStatusGroup,
    ProblemFlag
)
SELECT
    pls.LoanStatusCode,
    pls.LoanStatusDescription,
    pls.LoanStatusGroup,
    pls.ProblemFlag

FROM PreparedLoanStatuses AS pls

WHERE pls.LoanStatusCode <> N'UNKNOWN'

AND NOT EXISTS
(
    SELECT 1

    FROM dbo.DimLoanStatus AS existing

    WHERE existing.LoanStatusCode =
          pls.LoanStatusCode
);
GO

/*==============================================================
  6. Validate DimLoanStatus
==============================================================*/

SELECT
    COUNT(*) AS TotalLoanStatusRows,
    COUNT(DISTINCT LoanStatusCode)
        AS DistinctLoanStatusCodes,
    SUM
    (
        CASE
            WHEN ProblemFlag = 1 THEN 1
            ELSE 0
        END
    ) AS ProblemStatusCount

FROM dbo.DimLoanStatus;
GO

/*==============================================================
  7. Display loaded loan-status records
==============================================================*/

SELECT
    LoanStatusKey,
    LoanStatusCode,
    LoanStatusDescription,
    LoanStatusGroup,
    ProblemFlag

FROM dbo.DimLoanStatus

ORDER BY
    CASE LoanStatusCode
        WHEN N'UNKNOWN' THEN 0
        WHEN N'A' THEN 1
        WHEN N'B' THEN 2
        WHEN N'C' THEN 3
        WHEN N'D' THEN 4
        ELSE 5
    END;
GO

/*==============================================================
  8. Compare source loan statuses with dimension values
==============================================================*/

SELECT
    COALESCE
    (
        NULLIF
        (
            UPPER
            (
                LTRIM
                (
                    RTRIM(l.[status])
                )
            ),
            N''
        ),
        N'UNKNOWN'
    ) AS SourceLoanStatus,

    COALESCE
    (
        dls.LoanStatusKey,
        0
    ) AS LoanStatusKey,

    COALESCE
    (
        dls.LoanStatusDescription,
        N'Unknown Loan Status'
    ) AS LoanStatusDescription,

    COALESCE
    (
        dls.LoanStatusGroup,
        N'Unknown'
    ) AS LoanStatusGroup,

    COALESCE
    (
        dls.ProblemFlag,
        0
    ) AS ProblemFlag,

    COUNT(*) AS LoanCount,

    SUM
    (
        TRY_CONVERT
        (
            DECIMAL(18,2),
            l.amount
        )
    ) AS TotalLoanAmount

FROM CzechBank_DW.dbo.loan AS l

LEFT JOIN dbo.DimLoanStatus AS dls
    ON dls.LoanStatusCode =
       COALESCE
       (
           NULLIF
           (
               UPPER
               (
                   LTRIM
                   (
                       RTRIM(l.[status])
                   )
               ),
               N''
           ),
           N'UNKNOWN'
       )

GROUP BY
    COALESCE
    (
        NULLIF
        (
            UPPER
            (
                LTRIM
                (
                    RTRIM(l.[status])
                )
            ),
            N''
        ),
        N'UNKNOWN'
    ),

    COALESCE
    (
        dls.LoanStatusKey,
        0
    ),

    COALESCE
    (
        dls.LoanStatusDescription,
        N'Unknown Loan Status'
    ),

    COALESCE
    (
        dls.LoanStatusGroup,
        N'Unknown'
    ),

    COALESCE
    (
        dls.ProblemFlag,
        0
    )

ORDER BY SourceLoanStatus;
GO

/*==============================================================
  9. Find source status values that did not map
==============================================================*/

SELECT DISTINCT
    l.[status] AS UnmappedLoanStatus

FROM CzechBank_DW.dbo.loan AS l

LEFT JOIN dbo.DimLoanStatus AS dls
    ON dls.LoanStatusCode =
       COALESCE
       (
           NULLIF
           (
               UPPER
               (
                   LTRIM
                   (
                       RTRIM(l.[status])
                   )
               ),
               N''
           ),
           N'UNKNOWN'
       )

WHERE dls.LoanStatusKey IS NULL;
GO