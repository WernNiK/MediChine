"""
Device Registry Management
Handles device-email associations and QR code access control
"""
import sqlite3
import os
from datetime import datetime
from typing import Optional, List, Dict
from contextlib import contextmanager
import time

# Use /tmp directory or current directory with proper permissions
DB_DIR = os.environ.get('DB_DIR', '/tmp')
DB_PATH = os.path.join(DB_DIR, "device_registry.db")

@contextmanager
def get_db_connection():
    """Context manager for database connections with retry logic"""
    # Ensure directory exists
    os.makedirs(DB_DIR, exist_ok=True)
    
    # Retry logic for locked database
    max_retries = 5
    retry_delay = 0.1  # 100ms
    
    for attempt in range(max_retries):
        try:
            # Enable WAL mode and set timeout for better concurrency
            conn = sqlite3.connect(
                DB_PATH,
                timeout=10.0,  # Wait up to 10 seconds for locks
                check_same_thread=False
            )
            conn.row_factory = sqlite3.Row
            
            # Enable Write-Ahead Logging for better concurrency
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA busy_timeout=10000")  # 10 seconds
            
            try:
                yield conn
                conn.commit()
                break  # Success, exit retry loop
            except sqlite3.OperationalError as e:
                if "database is locked" in str(e).lower() and attempt < max_retries - 1:
                    print(f"⚠️ Database locked, retrying ({attempt + 1}/{max_retries})...")
                    conn.rollback()
                    conn.close()
                    time.sleep(retry_delay * (attempt + 1))  # Exponential backoff
                    continue
                else:
                    conn.rollback()
                    raise e
            except Exception as e:
                conn.rollback()
                raise e
            finally:
                conn.close()
                
        except sqlite3.OperationalError as e:
            if "database is locked" in str(e).lower() and attempt < max_retries - 1:
                print(f"⚠️ Database locked on connect, retrying ({attempt + 1}/{max_retries})...")
                time.sleep(retry_delay * (attempt + 1))
                continue
            else:
                raise e

def init_registry_db():
    """Initialize the device registry database"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Device registrations table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS device_registrations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT UNIQUE NOT NULL,
                owner_email TEXT NOT NULL,
                registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_connected TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                firebase_url TEXT,
                is_active BOOLEAN DEFAULT 1,
                UNIQUE(device_id)
            )
        ''')
        
        # Device connection history
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS connection_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT NOT NULL,
                email TEXT NOT NULL,
                action TEXT NOT NULL,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                success BOOLEAN DEFAULT 1,
                notes TEXT
            )
        ''')
        
        # Create indexes for faster lookups
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_device_id 
            ON device_registrations(device_id)
        ''')
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_owner_email 
            ON device_registrations(owner_email)
        ''')
        
        conn.commit()
        print("✅ Device registry database initialized")

def is_device_registered(device_id: str) -> bool:
    """Check if a device is already registered"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT COUNT(*) as count FROM device_registrations WHERE device_id = ? AND is_active = 1",
            (device_id,)
        )
        result = cursor.fetchone()
        return result['count'] > 0

def get_device_owner(device_id: str) -> Optional[str]:
    """Get the owner email of a device"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT owner_email FROM device_registrations WHERE device_id = ? AND is_active = 1",
            (device_id,)
        )
        result = cursor.fetchone()
        return result['owner_email'] if result else None

def register_device(device_id: str, owner_email: str, firebase_url: str) -> Dict:
    """
    Register a device to an email account
    Returns success status and message
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Check if device is already registered to another email
        existing_owner = get_device_owner(device_id)
        if existing_owner and existing_owner != owner_email:
            log_connection_attempt(device_id, owner_email, "register_denied", False, 
                                  f"Device already owned by {existing_owner}")
            return {
                "success": False,
                "message": f"Access denied: This device is already registered to another account",
                "error_code": "DEVICE_ALREADY_REGISTERED"
            }
        
        # Check if device exists but is inactive (previously disconnected)
        cursor.execute(
            "SELECT * FROM device_registrations WHERE device_id = ? AND is_active = 0",
            (device_id,)
        )
        inactive_device = cursor.fetchone()
        
        if inactive_device:
            # Reactivate the device
            cursor.execute(
                """UPDATE device_registrations 
                   SET is_active = 1, owner_email = ?, last_connected = ?, firebase_url = ?
                   WHERE device_id = ?""",
                (owner_email, datetime.now(), firebase_url, device_id)
            )
            log_connection_attempt(device_id, owner_email, "reactivate", True, "Device reactivated")
            return {
                "success": True,
                "message": "Device reconnected successfully",
                "action": "reactivated"
            }
        
        # Register new device
        try:
            cursor.execute(
                """INSERT INTO device_registrations (device_id, owner_email, firebase_url, last_connected)
                   VALUES (?, ?, ?, ?)
                   ON CONFLICT(device_id) DO UPDATE SET
                   last_connected = ?,
                   firebase_url = ?""",
                (device_id, owner_email, firebase_url, datetime.now(), datetime.now(), firebase_url)
            )
            log_connection_attempt(device_id, owner_email, "register", True, "Device registered successfully")
            
            return {
                "success": True,
                "message": "Device registered successfully",
                "action": "registered"
            }
        except sqlite3.IntegrityError as e:
            log_connection_attempt(device_id, owner_email, "register_error", False, str(e))
            return {
                "success": False,
                "message": "Failed to register device",
                "error_code": "DATABASE_ERROR"
            }

def disconnect_device(device_id: str, owner_email: str) -> Dict:
    """
    Disconnect a device from an account
    Marks the device as inactive instead of deleting
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Verify ownership
        current_owner = get_device_owner(device_id)
        if not current_owner:
            return {
                "success": False,
                "message": "Device not found or already disconnected",
                "error_code": "DEVICE_NOT_FOUND"
            }
        
        if current_owner != owner_email:
            log_connection_attempt(device_id, owner_email, "disconnect_denied", False, 
                                  f"Not owner. Actual owner: {current_owner}")
            return {
                "success": False,
                "message": "Access denied: You don't own this device",
                "error_code": "NOT_OWNER"
            }
        
        # Mark device as inactive
        cursor.execute(
            "UPDATE device_registrations SET is_active = 0 WHERE device_id = ?",
            (device_id,)
        )
        
        log_connection_attempt(device_id, owner_email, "disconnect", True, "Device disconnected")
        
        return {
            "success": True,
            "message": "Device disconnected successfully"
        }

def get_user_devices(owner_email: str) -> List[Dict]:
    """Get all active devices for a user"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """SELECT device_id, firebase_url, registered_at, last_connected
               FROM device_registrations 
               WHERE owner_email = ? AND is_active = 1
               ORDER BY last_connected DESC""",
            (owner_email,)
        )
        
        devices = []
        for row in cursor.fetchall():
            devices.append({
                "device_id": row['device_id'],
                "firebase_url": row['firebase_url'],
                "registered_at": row['registered_at'],
                "last_connected": row['last_connected']
            })
        
        return devices

def log_connection_attempt(device_id: str, email: str, action: str, 
                          success: bool, notes: str = ""):
    """Log all connection attempts for audit purposes"""
    # Use a separate connection to avoid nested transactions
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """INSERT INTO connection_history (device_id, email, action, success, notes)
                   VALUES (?, ?, ?, ?, ?)""",
                (device_id, email, action, success, notes)
            )
    except Exception as e:
        # Don't fail the main operation if logging fails
        print(f"⚠️ Failed to log connection attempt: {e}")

def update_last_connected(device_id: str):
    """Update the last connected timestamp for a device"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE device_registrations SET last_connected = ? WHERE device_id = ?",
            (datetime.now(), device_id)
        )

def get_device_info(device_id: str) -> Optional[Dict]:
    """Get detailed information about a device"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """SELECT * FROM device_registrations 
               WHERE device_id = ? AND is_active = 1""",
            (device_id,)
        )
        row = cursor.fetchone()
        
        if not row:
            return None
        
        return {
            "device_id": row['device_id'],
            "owner_email": row['owner_email'],
            "firebase_url": row['firebase_url'],
            "registered_at": row['registered_at'],
            "last_connected": row['last_connected'],
            "is_active": bool(row['is_active'])
        }

def cleanup_old_connections(days: int = 90):
    """
    Clean up old inactive device registrations
    (Optional maintenance function)
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """DELETE FROM device_registrations 
               WHERE is_active = 0 
               AND last_connected < datetime('now', '-' || ? || ' days')""",
            (days,)
        )
        deleted_count = cursor.rowcount
        print(f"🧹 Cleaned up {deleted_count} old device registrations")
        return deleted_count