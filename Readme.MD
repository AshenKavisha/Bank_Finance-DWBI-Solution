# Member 3 — ETL, Fact Loading & Data Mart Development

This README documents my contribution to the **Retail Banking Data Warehouse & Business Intelligence Solution**, a collaborative academic project for IT3101 – Data Warehousing and Business Intelligence at the Sri Lanka Institute of Information Technology (SLIIT).

> **My contribution:** ETL / transaction fact loading, data mart development, and reconciliation/validation.

## Project Context
The team used the 1999 Czech Financial Dataset (Berka dataset), containing accounts, clients, transactions, loans, cards, standing orders and district demographics. The overall solution organizes this data into a dimensional warehouse and provides marts for transaction trends and district-level loan analysis.

## My Responsibilities

### 1. ETL Pipeline
The process follows this general sequence:

1. Extract source records from the prepared source/staging environment.
2. Stage records for processing and validation.
3. Transform and standardize data required by the warehouse model.
4. Load dimensions and resolve their surrogate keys.
5. Load fact records using the appropriate dimension keys.
6. Validate the results and reconcile important measures.

The goal is to maintain consistency between the source data, dimensional warehouse and reporting layer.

### 2. Transaction Fact Loading
**Script noted in the project handover:** `18_load_fact_transaction.sql`

The transaction fact-loading work includes:
- Incremental insertion of transaction records
- Mapping source business keys to dimension surrogate keys
- Loading transaction measures into `FactTransaction`
- Checking for duplicate fact records
- Checking for missing dimension-key mappings
- Supporting row-count and financial-total reconciliation

The transaction fact is designed at the grain of **one row per individual transaction recorded against one bank account**.

Measures in the dimensional design include transaction count, transaction amount, inflow, outflow, signed/net amount and balance after transaction. Refer to the actual SQL script for the exact implemented fields.

### 3. Data Mart Development
**Script noted in the project handover:** `19_create_retail_banking_data_mart.sql`

I worked on the data-mart layer, including the `mart` schema and these analytical tables:

#### `mart.MonthlyTransactionPerformance`
Summarizes transaction activity by month and is intended to support:
- Monthly transaction-volume analysis
- Comparison of transaction amounts over time
- Inflow and outflow analysis
- Review of net transaction movement

#### `mart.DistrictLoanPerformance`
Summarizes loan activity by district and is intended to support:
- Comparison of loan counts across districts
- Comparison of loan amounts by district
- Review of duration/payment-related measures where included
- Analysis of problem-loan counts where included

The exact columns and aggregation logic should be taken from the final SQL script on the published branch.

### 4. Validation and Reconciliation
Validation focuses on:
- Checking loaded row counts
- Detecting duplicate fact records
- Identifying missing dimension-key mappings
- Comparing data-mart aggregates with warehouse totals
- Verifying that aggregation does not unintentionally change important financial measures

Include specific test results or screenshots only when captured from the final successful execution.

## Tools and Technologies
- Microsoft SQL Server
- T-SQL
- SQL scripts for fact loading and data-mart creation
- Dimensional data warehouse concepts
- ETL, surrogate-key mapping, incremental loading, validation and reconciliation

Python/pandas and the CSV, Excel and JSON source formats belong to the wider team solution; list them as my direct work only if they were part of my own implementation.

## Key Deliverables

| Deliverable | Purpose |
|---|---|
| `18_load_fact_transaction.sql` | Transaction fact loading, key resolution and validation |
| `19_create_retail_banking_data_mart.sql` | Creates the retail banking data-mart structures |
| `mart.MonthlyTransactionPerformance` | Monthly transaction analysis |
| `mart.DistrictLoanPerformance` | District-level loan analysis |
| Reconciliation checks | Help verify consistency between warehouse and mart data |

These filenames and descriptions come from the project handover notes. Confirm filenames and final contents on the branch before publishing.

## How to Review My Work
1. Check out my branch.
2. Review `18_load_fact_transaction.sql` and verify database names and dependencies.
3. Ensure required source, staging and dimension tables exist and are populated.
4. Execute the fact-loading script in the documented order.
5. Review `19_create_retail_banking_data_mart.sql` and execute it after its warehouse dependencies are ready.
6. Run the project's validation/reconciliation queries and compare outputs with documented results.

**Safety note:** Check database targets and dependencies before running scripts. Do not execute scripts against an unrelated or production database.

## What I Learned
- How ETL connects source data to a dimensional warehouse
- Why dimensions are loaded before fact records
- How surrogate keys link fact tables to dimensions
- Why transaction and loan facts have different grains
- How data marts simplify analytical queries
- Why reconciliation and data-quality checks matter for financial reporting
- How to collaborate using Git branches and shared project documentation

## Project Outcome
My contribution focused on the analytical layer between detailed warehouse data and business-focused summaries. The transaction and loan marts are designed to make monthly transaction patterns and district-level loan performance easier to explore.

For a portfolio, add screenshots of successful SQL execution, result tables, reconciliation outputs and any BI visuals included in the final project.

## Academic Credit
**Module:** IT3101 – Data Warehousing and Business Intelligence  
**Institution:** Sri Lanka Institute of Information Technology (SLIIT)  
**Academic year:** Year 3, Semester 1 – 2026

This was a team assignment. This README describes my contribution and should be used alongside the team's main README and final report.
