"""Loads all raw CSVs into a local SQLite database, one table per file."""
import sqlite3
import pandas as pd
from pathlib import Path

RAW_DIR = Path(__file__).parent.parent / "data" / "raw"
DB_PATH = Path(__file__).parent.parent / "data" / "trucking.db"

conn = sqlite3.connect(DB_PATH)

for csv_file in sorted(RAW_DIR.glob("*.csv")):
    table_name = csv_file.stem
    df = pd.read_csv(csv_file)
    df.to_sql(table_name, conn, if_exists="replace", index=False)
    print(f"Loaded {table_name}: {len(df)} rows, {len(df.columns)} columns")

conn.close()
print(f"\nDatabase ready at {DB_PATH}")
