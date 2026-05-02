import sqlite3
from pathlib import Path

# Database is at BACKEND/config/db.sqlite3
db_path = Path(__file__).parent / "config" / "db.sqlite3"

if not db_path.exists():
    print(f"Database not found at: {db_path.absolute()}")
    exit(1)

print(f"Using database: {db_path.absolute()}")
conn = sqlite3.connect(str(db_path))
cursor = conn.cursor()

try:
    cursor.execute("ALTER TABLE seats ADD COLUMN is_diseased BOOLEAN DEFAULT 0 NOT NULL")
    print("Added is_diseased column")
except sqlite3.OperationalError as e:
    print(f"is_diseased: {e}")

try:
    cursor.execute("ALTER TABLE seats ADD COLUMN disease_name VARCHAR(128)")
    print("Added disease_name column")
except sqlite3.OperationalError as e:
    print(f"disease_name: {e}")

try:
    cursor.execute("ALTER TABLE seats ADD COLUMN disease_confidence FLOAT")
    print("Added disease_confidence column")
except sqlite3.OperationalError as e:
    print(f"disease_confidence: {e}")

try:
    cursor.execute("ALTER TABLE seats ADD COLUMN last_disease_check_ts INTEGER DEFAULT 0 NOT NULL")
    print("Added last_disease_check_ts column")
except sqlite3.OperationalError as e:
    print(f"last_disease_check_ts: {e}")

conn.commit()
conn.close()
print("Database updated successfully!")
