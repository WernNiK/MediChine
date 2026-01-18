import sqlite3
import os

BASE_DIR = "/tmp/devices"
os.makedirs(BASE_DIR, exist_ok=True)

def get_history_db_path(device_id: str) -> str:
    safe_device_id = device_id.replace(":", "_").replace("/", "_")
    return os.path.join(BASE_DIR, f"{safe_device_id}_history.db")

def get_history_db_connection(device_id: str):
    db_path = get_history_db_path(device_id)
    return sqlite3.connect(db_path)

def init_history_db(device_id: str):
    conn = get_history_db_connection(device_id)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medicine_name TEXT,
            container_id INTEGER,
            quantity INTEGER,
            scheduled_time TEXT,
            scheduled_days TEXT,
            datetime_taken TEXT,
            time_taken TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()

