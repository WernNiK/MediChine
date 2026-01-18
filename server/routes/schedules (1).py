import sqlite3
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, field_validator
from datetime import datetime
from database import get_db_connection_for_device
from context import firebase_config_store
import re

router = APIRouter()

# Email validation regex
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

# ✅ Updated Schedule model with email
class Schedule(BaseModel):
    email: str  # ✅ Required
    container_id: int
    name: str
    time: str
    days: str
    quantity: int
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError('Invalid email format')
        return v.lower()

class ScheduleUpdate(BaseModel):
    email: str  # ✅ Required
    container_id: int = 0  # Optional, 0 means keep existing
    name: str
    time: str
    days: str
    quantity: int
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError('Invalid email format')
        return v.lower()

def get_device_conn():
    """Helper to get database connection"""
    required = ["firebase_url", "device_id", "auth_token"]
    for key in required:
        if key not in firebase_config_store:
            raise HTTPException(
                status_code=500,
                detail=f"❌ firebase_config_store missing keys: {key}"
            )

    return get_db_connection_for_device(
        firebase_config_store["device_id"],
        firebase_config_store["firebase_url"],
        firebase_config_store["auth_token"]
    )

@router.post("/save_schedule")
def save_schedule(schedule: Schedule):
    """
    Save a new schedule - ALWAYS creates new entries
    Multiple schedules per container are allowed
    Email is validated by middleware
    """
    conn = None
    try:
        print(f"[INFO] Saving schedule: container_id={schedule.container_id} name='{schedule.name}' time='{schedule.time}' days='{schedule.days}' quantity={schedule.quantity}")
        print(f"[INFO] Request from email: {schedule.email}")

        # Normalize time format
        time_obj = datetime.strptime(schedule.time, "%I:%M %p")
        formatted_time = time_obj.strftime("%I:%M %p")

        conn = get_device_conn()
        
        # ✅ FIX: ALWAYS insert new schedule (removed the UPDATE logic)
        conn.execute(
            "INSERT INTO schedules (container_id, name, time, days, quantity) VALUES (?, ?, ?, ?, ?)",
            (schedule.container_id, schedule.name, formatted_time, schedule.days, schedule.quantity)
        )
        conn.commit()
        
        # Get the ID of the newly created schedule
        cursor = conn.execute("SELECT last_insert_rowid()")
        new_id = cursor.fetchone()[0]
        
        print(f"[INFO] ✅ Created new schedule (ID: {new_id}) for container {schedule.container_id}")
        return {
            "message": "✅ Schedule saved successfully",
            "schedule_id": new_id
        }
    
    except ValueError as e:
        print(f"[ERROR] Invalid time format: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid time format: {e}")
    except Exception as e:
        print(f"[ERROR] Failed to save schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

@router.get("/get_schedules/{container_id}")
def get_schedules(container_id: int, email: str):
    """
    Get ALL schedules for a specific container
    Email required as query parameter and validated by middleware
    """
    conn = None
    try:
        print(f"[INFO] Fetching schedules for container {container_id}")
        print(f"[INFO] Request from email: {email}")
        
        conn = get_device_conn()
        cursor = conn.execute(
            "SELECT id, name, time, days, quantity FROM schedules WHERE container_id = ? ORDER BY time ASC",
            (container_id,),
        )
        schedules = [
            {
                "id": row[0],
                "name": row[1],
                "time": row[2],
                "days": row[3],
                "quantity": row[4],
            }
            for row in cursor.fetchall()
        ]
        
        print(f"[INFO] ✅ Found {len(schedules)} schedule(s) for container {container_id}")
        return {"schedules": schedules}
    except Exception as e:
        print(f"[ERROR] Failed to retrieve schedules: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

@router.get("/schedule/{schedule_id}")
def get_schedule(schedule_id: int, email: str):
    """
    Get a specific schedule by ID
    Email required as query parameter and validated by middleware
    """
    conn = None
    try:
        print(f"[INFO] Fetching schedule {schedule_id}")
        print(f"[INFO] Request from email: {email}")
        
        conn = get_device_conn()
        conn.row_factory = sqlite3.Row
        cursor = conn.execute("SELECT * FROM schedules WHERE id = ?", (schedule_id,))
        row = cursor.fetchone()

        if not row:
            raise HTTPException(status_code=404, detail="Schedule not found")

        return {
            "id": row["id"],
            "container_id": row["container_id"],
            "name": row["name"],
            "time": row["time"],
            "days": row["days"],
            "quantity": row["quantity"],
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] Failed to fetch schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()
            
@router.put("/update_schedule/{schedule_id}")
def update_schedule(schedule_id: int, schedule: ScheduleUpdate):
    """
    Update an existing schedule
    Email is validated by middleware
    """
    conn = None
    try:
        print(f"[INFO] Updating schedule {schedule_id}")
        print(f"[INFO] Request from email: {schedule.email}")
        
        conn = get_device_conn()
        conn.row_factory = sqlite3.Row

        # If container_id is 0, keep the existing one
        if schedule.container_id == 0:
            cursor = conn.execute("SELECT container_id FROM schedules WHERE id = ?", (schedule_id,))
            existing = cursor.fetchone()
            if not existing:
                raise HTTPException(status_code=404, detail="Schedule not found")
            schedule.container_id = existing["container_id"]

        # Normalize time format
        time_obj = datetime.strptime(schedule.time, "%I:%M %p")
        formatted_time = time_obj.strftime("%I:%M %p")

        result = conn.execute(
            "UPDATE schedules SET container_id = ?, name = ?, time = ?, days = ?, quantity = ? WHERE id = ?",
            (
                schedule.container_id,
                schedule.name,
                formatted_time,
                schedule.days,
                schedule.quantity,
                schedule_id
            )
        )
        conn.commit()

        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Schedule not found")

        print(f"[INFO] ✅ Updated schedule {schedule_id}")
        return {"message": "✅ Schedule updated successfully"}
    
    except ValueError as e:
        print(f"[ERROR] Invalid time format: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid time format: {e}")
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] Failed to update schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

@router.delete("/delete_schedule/{schedule_id}")
def delete_schedule(schedule_id: int, email: str):
    """
    Delete a specific schedule
    Email required as query parameter and validated by middleware
    """
    conn = None
    try:
        print(f"[INFO] Deleting schedule {schedule_id}")
        print(f"[INFO] Request from email: {email}")
        
        conn = get_device_conn()
        result = conn.execute("DELETE FROM schedules WHERE id = ?", (schedule_id,))
        conn.commit()

        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Schedule not found")

        print(f"[INFO] ✅ Deleted schedule {schedule_id}")
        return {"message": "✅ Schedule deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        print(f"[ERROR] Failed to delete schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

@router.delete("/delete_all_schedules/{container_id}")
def delete_all_schedules(container_id: int, email: str):
    """
    Delete all schedules for a specific container
    Email required as query parameter and validated by middleware
    """
    conn = None
    try:
        print(f"[INFO] Deleting all schedules for container {container_id}")
        print(f"[INFO] Request from email: {email}")
        
        conn = get_device_conn()
        result = conn.execute("DELETE FROM schedules WHERE container_id = ?", (container_id,))
        deleted_count = result.rowcount
        conn.commit()
        
        print(f"[INFO] ✅ Deleted {deleted_count} schedule(s) from container {container_id}")
        return {
            "message": f"✅ All schedules deleted successfully",
            "deleted_count": deleted_count
        }
    except Exception as e:
        print(f"[ERROR] Failed to delete all schedules: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

@router.get("/get_all_schedules")
def get_all_schedules(email: str):
    """
    Get all schedules across all containers
    Email required as query parameter and validated by middleware
    """
    conn = None
    try:
        print(f"[INFO] Fetching all schedules")
        print(f"[INFO] Request from email: {email}")
        
        conn = get_device_conn()
        cursor = conn.execute(
            "SELECT id, container_id, name, time, days, quantity FROM schedules ORDER BY container_id, time ASC"
        )
        schedules = [
            {
                "id": row[0],
                "container_id": row[1],
                "name": row[2],
                "time": row[3],
                "days": row[4],
                "quantity": row[5],
            }
            for row in cursor.fetchall()
        ]
        
        print(f"[INFO] ✅ Found {len(schedules)} total schedule(s)")
        return {"schedules": schedules, "total_count": len(schedules)}
    except Exception as e:
        print(f"[ERROR] Failed to retrieve all schedules: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()