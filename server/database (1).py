import sqlite3
import os

BASE_DIR = "/tmp/devices"
os.makedirs(BASE_DIR, exist_ok=True)

def get_device_db_path(device_id: str, firebase_url: str, auth_token: str) -> str:
    # sanitize filename
    safe_device_id = device_id.replace(":", "_").replace("/", "_")
    return os.path.join(BASE_DIR, f"{safe_device_id}.db")

def get_db_connection_for_device(device_id: str, firebase_url: str, auth_token: str):
    db_path = get_device_db_path(device_id, firebase_url, auth_token)
    return sqlite3.connect(db_path)

def init_device_db(device_id: str, firebase_url: str, auth_token: str):
    conn = get_db_connection_for_device(device_id, firebase_url, auth_token)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS schedules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            container_id INTEGER,
            name TEXT,
            time TEXT,
            days TEXT,
            quantity INTEGER
        )
    """)
    conn.commit()
    conn.close()

def close_db_connection(conn):
    """Safely closes the DB connection if it exists."""
    if conn:
        conn.close()

