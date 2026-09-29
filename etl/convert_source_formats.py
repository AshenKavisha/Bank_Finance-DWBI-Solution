
from pathlib import Path
import pandas as pd

raw_folder = Path("data/raw")

# Convert card.csv to JSON
card_data = pd.read_csv(
    raw_folder / "card.csv",
    sep=";"
)

card_data.to_json(
    raw_folder / "card.json",
    orient="records",
    indent=4,
    force_ascii=False
)

# Convert loan.csv to Excel
loan_data = pd.read_csv(
    raw_folder / "loan.csv",
    sep=";"
)

loan_data.to_excel(
    raw_folder / "loan.xlsx",
    index=False,
    sheet_name="Loans"
)

print("card.json created successfully")
print("loan.xlsx created successfully")