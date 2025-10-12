import re
import sys
from pathlib import Path

import mysql.connector
from mysql.connector import Error

try:
    from config import db_config
except Exception as e:
    print(f"Failed to import db_config from config.py: {e}")
    sys.exit(1)

schema_path = Path(__file__).parent / "schema.sql"
if not schema_path.exists():
    print(f"Schema file not found: {schema_path}")
    sys.exit(1)

text = schema_path.read_text(encoding="utf-8")

# Normalize line endings
text = text.replace("\r\n", "\n")

# Remove SQL comments starting with --
lines = [ln for ln in text.split("\n") if not ln.strip().startswith("--")]
text = "\n".join(lines)

# Remove DELIMITER directives and convert END// to END;
text = text.replace("DELIMITER //", "")
text = text.replace("DELIMITER ;", "")
text = text.replace("END//", "END;")

# Simple stateful parser to group CREATE PROCEDURE/FUNCTION/TRIGGER blocks
statements = []
current = []
inside_block = False

block_starters = ("CREATE PROCEDURE", "CREATE FUNCTION", "CREATE TRIGGER")

for ln in text.split("\n"):
    if not ln.strip():
        continue
    if any(ln.strip().upper().startswith(bs) for bs in block_starters):
        inside_block = True
    current.append(ln)
    stripped = ln.strip()
    if inside_block:
        if stripped.upper().endswith("END;"):
            statements.append("\n".join(current))
            current = []
            inside_block = False
    else:
        if stripped.endswith(";"):
            statements.append("\n".join(current))
            current = []

# Append any remaining statement
if current:
    statements.append("\n".join(current))

print(f"Prepared {len(statements)} statements to execute.")

# Execute statements one by one
conn = None
try:
    conn = mysql.connector.connect(**db_config)
    if not conn.is_connected():
        print("DB connection failed.")
        sys.exit(1)
    cur = conn.cursor()
    for i, stmt in enumerate(statements, 1):
        s = stmt.strip()
        if not s:
            continue
        try:
            head = s.split("\n", 1)[0][:120]
            print(f"Executing [{i}/{len(statements)}]: {head}...")
            cur.execute(s)
        except Error as e:
            print(f"Error executing statement {i}: {e}")
            # Continue to next, but print the start of the statement for context
            print("Statement start:")
            print(s[:500])
    conn.commit()
    print("Schema applied successfully.")
except Error as e:
    print(f"DB Error: {e}")
    sys.exit(1)
finally:
    try:
        if conn:
            conn.close()
    except Exception:
        pass
