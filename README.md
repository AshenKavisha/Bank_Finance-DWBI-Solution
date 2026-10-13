# Retail Banking Data Warehouse & Business Intelligence Solution

An academic data warehousing and BI project using the 1999 Czech Financial Dataset (Berka dataset). The solution brings banking data into an analytical model and creates data marts for transaction and loan performance analysis.

**Module:** IT3101 – Data Warehousing and Business Intelligence  
**Institution:** Sri Lanka Institute of Information Technology (SLIIT)  
**Academic year:** Year 3, Semester 1 – 2026

## Table of Contents
- [Overview](#overview)
- [Business Problem](#business-problem)
- [Objectives](#objectives)
- [Dataset and Sources](#dataset-and-sources)
- [Architecture](#architecture)
- [Dimensional Model](#dimensional-model)
- [ETL Workflow](#etl-workflow)
- [Data Marts](#data-marts)
- [Technology Stack](#technology-stack)
- [Repository Structure](#repository-structure)
- [Setup and Execution](#setup-and-execution)
- [Validation](#validation)
- [Team Contributions](#team-contributions)
- [Limitations](#limitations)
- [Future Improvements](#future-improvements)

## Overview
The project demonstrates a layered data warehouse workflow for retail banking analytics. It uses source entities such as accounts, clients, transactions, loans, cards, standing orders and district demographics. The data is prepared for analysis through staging, transformation, dimensional modelling, fact loading and data marts.

## Business Problem
Operational banking systems are optimized for recording individual events. It can be difficult to answer cross-cutting analytical questions about transaction trends, cash flow and regional loan activity. This project organizes the data to support those analyses.

## Objectives
- Integrate related banking data into an analytical environment.
- Demonstrate ingestion of data in different formats.
- Transform and validate records for dimensional analysis.
- Model transaction and loan processes as separate fact tables.
- Load dimensions and facts using surrogate-key mappings.
- Build data marts for monthly transaction and district loan analysis.
- Reconcile important counts and measures.

## Dataset and Sources
The project uses the **1999 Czech Financial Dataset**, commonly called the **Berka dataset**, originally prepared for the PKDD'99 Discovery Challenge and obtained through a Kaggle mirror.

| Table | Description |
|---|---|
| `account` | Account details and statement frequency |
| `client` | Client demographic details |
| `disp` | Relationships between clients and accounts |
| `order` | Standing payment orders |
| `trans` | Individual account transactions |
| `loan` | Loan amount, duration, payment and status |
| `card` | Card type and issue date |
| `district` | District-level demographic and economic information |

### Source formats
- CSV: core banking tables and district reference data
- Excel (`.xlsx`): loan data
- JSON: card data
- REST API: public-holiday data intended to enrich the date dimension

**Data-origin note:** The CSV, Excel, JSON and district files are derived from the same underlying Berka dataset; some tables were restructured into different formats for multi-format ingestion. The holiday API is a separate external source. Confirm the final repository and run evidence before claiming the API integration was fully completed.

## Architecture
The solution is organized into these logical layers:

1. **Source layer** — CSV, Excel, JSON and external API data.
2. **Integration / ETL layer** — extraction, validation, cleaning, standardization and transformation.
3. **Staging layer** — temporary landing and validation area.
4. **Data warehouse layer** — integrated dimensional facts and dimensions.
5. **Data mart layer** — summarized tables for specific analytical needs.
6. **Presentation layer** — intended BI reporting and visualization, such as Power BI.

```text
CSV / Excel / JSON / Holiday API
              |
              v
      Extract and Validate
              |
              v
       Staging Database
              |
              v
   Transform and Standardize
              |
              v
      Dimensional Warehouse
        /             \
       v               v
FactTransaction     FactLoan
       |               |
       v               v
Monthly Transaction  District Loan
Performance Mart     Performance Mart
        \              /
         v            v
        BI / Reporting
```

This is a logical view of the solution. Confirm the final deployed components and BI connection before describing them as live or automated.

## Dimensional Model
The design uses a **fact constellation (galaxy schema)** with two fact tables because transactions and loans have different grains and measures.

### `FactTransaction`
**Grain:** One row per individual transaction recorded against one bank account.

Measures in the design include:
- Transaction count
- Transaction amount
- Inflow amount
- Outflow amount
- Signed/net amount
- Balance after transaction

The model references date, account, district, transaction type and operation dimensions. The transaction identifier may be retained as a degenerate dimension/business identifier.

### `FactLoan`
**Grain:** One row per loan issued to a bank account.

Measures in the design include:
- Loan count
- Loan amount
- Loan duration in months
- Monthly payment
- Expected payment amount
- Problem-loan count

The model references loan date, account, district and loan-status dimensions.

### Dimensions
- `DimDate`
- `DimAccount`
- `DimClient`
- `DimDistrict`
- `DimTransactionType`
- `DimOperation`
- `DimLoanStatus`

The design uses surrogate integer keys in dimensions while retaining operational identifiers as business keys. It also specifies an unknown dimension member (key `0`) and effective-date attributes for applicable dimensions.

## ETL Workflow
The ETL workflow follows these stages:

1. **Extract** source records from prepared files and/or the source database.
2. **Stage** records for processing and validation.
3. **Transform** records through cleaning, standardization, derived measures and source-to-dimension mappings.
4. **Load dimensions** so surrogate keys are available.
5. **Load facts** after resolving dimension keys.
6. **Validate and reconcile** counts, key mappings and analytical totals.

The Member 3 handover notes identify `18_load_fact_transaction.sql` as the transaction fact-loading script, with incremental insertion, dimension-key resolution and validation. They identify `19_create_retail_banking_data_mart.sql` as the data-mart creation script. Confirm that these filenames and their final versions exist on the branch being published.

## Data Marts

### `mart.MonthlyTransactionPerformance`
Summarizes transaction activity by month. Depending on the final script, measures may include transaction count, total amount, inflow, outflow and net/signed amount.

**Business use:** Compare monthly transaction volumes and cash-flow movement.

### `mart.DistrictLoanPerformance`
Summarizes loan activity by district. Depending on the final script, measures may include loan count, total loan amount, duration/payment-related measures and problem-loan count.

**Business use:** Compare loan activity and portfolio characteristics across districts.

Check the SQL script for the exact columns and aggregation logic.

## Technology Stack
The project materials identify or describe:
- **Microsoft SQL Server / T-SQL** — source, staging and warehouse processing
- **Python and pandas** — loading the Excel loan source
- **SQL Server JSON functions** — processing card JSON data
- **CSV, Excel and JSON** — source data formats
- **REST API** — public-holiday enrichment
- **Power BI** — intended presentation and reporting layer

Only describe a technology as implemented if the final repository and execution evidence confirm its use.

## Repository Structure
The exact layout can vary by branch. Adjust this example to match the committed files.

```text
.
├── data/       # Source files or data documentation, if committed
├── sql/        # SQL scripts for source, staging, warehouse and marts
├── etl/        # ETL scripts, if organized separately
├── reports/    # Reports, diagrams and evidence, if committed
└── README.md
```

Avoid committing credentials, API keys, private data or oversized database backups. If data or `.bak` files are too large for GitHub, share them through an approved separate location and document the expected path.

## Setup and Execution

### Prerequisites
- Microsoft SQL Server
- SQL Server Management Studio (SSMS) or a compatible SQL client
- Python with `pandas` if the Excel-loading script is used
- Source files at the paths expected by the scripts
- API configuration if holiday enrichment is enabled

### General execution sequence
1. Clone the repository and check out the required branch.
2. Review script configuration, database names and expected file paths.
3. Prepare the source files.
4. Create source/staging databases and tables using the provided scripts.
5. Load CSV, Excel and JSON data using the project's documented methods.
6. Run transformations and dimension-loading scripts in dependency order.
7. Load fact tables after dimensions are populated.
8. Run the data-mart creation script.
9. Execute validation and reconciliation queries.
10. Connect the final analytical tables to the BI tool if this is included in the final project.

This is a general sequence, not a guarantee that all steps are automated. Use the actual order and paths documented in the committed scripts, and check database targets before execution.

## Validation
The project work describes checks such as:
- Comparing source and loaded row counts
- Detecting duplicate fact records
- Identifying missing dimension-key mappings
- Comparing mart aggregates with warehouse totals
- Checking transaction and loan measures after aggregation

Add exact counts, test outputs and screenshots only after confirming them from the final run.

## Team Contributions
Based on the report and handover materials:
- **Member 1:** Dataset selection, business scenario, source preparation and source-loading preparation.
- **Member 3:** ETL / transaction fact loading, data mart development and reconciliation, including the scripts listed above.
- **Other members:** Warehouse architecture, dimensional design, BI/presentation tasks and other assigned deliverables.

Update this section with agreed member names and verified contributions before publishing.

## Limitations
- The restructured source files derive from the same underlying Berka dataset.
- Describe holiday API enrichment as completed only if extraction and date-dimension loading were tested.
- Exact row counts and performance benchmarks are omitted until verified against the final run.
- Describe dashboards and refresh automation as completed only if the final project includes working evidence.
- This is an academic demonstration, not a production banking system.

## Future Improvements
- Automate ETL orchestration and repeatable runs.
- Add logging, error handling and restart/recovery support.
- Produce a formal data-quality and reconciliation report.
- Develop interactive BI dashboards with date and district filters.
- Improve performance and incremental refresh.
- Document configuration, sample outputs and recovery procedures.

## Academic Context
Developed for **IT3101 – Data Warehousing and Business Intelligence**, Year 3, Semester 1, 2026, at **Sri Lanka Institute of Information Technology (SLIIT)**.

For a portfolio or LinkedIn post, describe your own contribution accurately and credit the team.
