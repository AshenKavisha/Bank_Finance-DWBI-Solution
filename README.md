## Member 3 – ETL Pipeline and Data Mart

### Responsibilities

Member 3 implemented the transformation and loading stages of the data warehouse pipeline using the staging tables prepared by Member 2.

### Work Completed

- Inspected and validated the staged source tables.
- Cleaned missing, duplicate, and inconsistent data.
- Standardized account frequency values.
- Converted transaction type and operation values into understandable English labels.
- Preserved problematic loan records for later analysis instead of deleting them.
- Created reusable cleaned staging tables.
- Loaded the following warehouse components:
  - `DimDistrict`
  - `DimAccount`
  - `DimClient`
  - Other required dimensions
  - Main fact table
- Used update-and-insert logic to prevent duplicate dimension records.
- Preserved unknown dimension members for unmatched or missing source values.
- Created the analytical data mart.
- Performed row-count, key, relationship, and reconciliation checks.
- Created a final SQL Server `.bak` backup for Member 4.

### ETL Flow

```mermaid
flowchart LR
    A[Raw source files] --> B[Member 2 staging tables]
    B --> C[Member 3 cleaning and transformation]
    C --> D[Clean staging tables]
    D --> E[Dimensions]
    D --> F[Fact table]
    E --> G[Analytical data mart]
    F --> G
    G --> H[Member 4 BI analysis]