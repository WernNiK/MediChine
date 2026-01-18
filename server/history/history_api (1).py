from fastapi import APIRouter, HTTPException
from context import firebase_config_store
from history.history import get_history_db_connection
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

def get_device_id_or_fail():
    """Helper to get device ID from config"""
    device_id = firebase_config_store.get("device_id")
    if not device_id:
        raise HTTPException(
            status_code=400, 
            detail="❌ No device_id found. Please scan QR code."
        )
    return device_id

@router.get("/history")
def get_history(email: str):
    """
    Fetch all history entries - email required as query parameter
    Email is validated by middleware
    """
    device_id = get_device_id_or_fail()
    
    conn = get_history_db_connection(device_id)
    try:
        history = conn.execute("""
            SELECT id, medicine_name, container_id, quantity, 
                   scheduled_time, scheduled_days, datetime_taken, time_taken
            FROM history 
            ORDER BY created_at DESC
        """).fetchall()
        
        results = []
        for row in history:
            results.append({
                "id": row[0],
                "medicine_name": row[1],
                "container_id": row[2],
                "quantity": row[3],
                "scheduled_time": row[4],
                "scheduled_days": row[5],
                "datetime_taken": row[6],
                "time_taken": row[7]
            })
        
        logger.info(f"✅ Fetched {len(results)} history entries for device {device_id}")
        return results
    
    except Exception as e:
        logger.error(f"❌ Failed to fetch history for device {device_id}: {e}")
        raise HTTPException(
            status_code=500, 
            detail=f"❌ Failed to fetch history: {e}"
        )
    finally:
        conn.close()

@router.delete("/delete_all_history")
def delete_all_history(email: str):
    """
    Delete all history entries - email required as query parameter
    Email is validated by middleware
    """
    device_id = get_device_id_or_fail()
    
    conn = get_history_db_connection(device_id)
    try:
        cursor = conn.execute("DELETE FROM history")
        deleted_count = cursor.rowcount
        conn.commit()
        
        logger.info(f"✅ Deleted {deleted_count} history entries for device {device_id}")
        return {
            "message": f"✅ All {deleted_count} history entries deleted",
            "deleted_count": deleted_count
        }
    
    except Exception as e:
        logger.error(f"❌ Failed to delete all history for device {device_id}: {e}")
        raise HTTPException(
            status_code=500, 
            detail=f"❌ Failed to delete all history: {e}"
        )
    finally:
        conn.close()

@router.delete("/delete_history/{history_id}")
def delete_history(history_id: int, email: str):
    """
    Delete specific history entry - email required as query parameter
    Email is validated by middleware
    """
    device_id = get_device_id_or_fail()
    
    conn = get_history_db_connection(device_id)
    try:
        cursor = conn.execute(
            "DELETE FROM history WHERE id = ?", 
            (history_id,)
        )
        
        if cursor.rowcount == 0:
            raise HTTPException(
                status_code=404, 
                detail="❌ History entry not found"
            )
        
        conn.commit()
        
        logger.info(f"✅ Deleted history entry {history_id} for device {device_id}")
        return {
            "message": f"✅ History entry {history_id} deleted"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Failed to delete history entry {history_id} for device {device_id}: {e}")
        raise HTTPException(
            status_code=500, 
            detail=f"❌ Failed to delete history: {e}"
        )
    finally:
        conn.close()

@router.get("/history/stats")
def get_history_stats(email: str):
    """
    Get history statistics - email required as query parameter
    Email is validated by middleware
    """
    device_id = get_device_id_or_fail()
    
    conn = get_history_db_connection(device_id)
    try:
        # Total entries
        total = conn.execute("SELECT COUNT(*) FROM history").fetchone()[0]
        
        # Entries by container
        by_container = conn.execute("""
            SELECT container_id, COUNT(*) as count
            FROM history
            GROUP BY container_id
        """).fetchall()
        
        # Recent entries (last 7 days)
        recent = conn.execute("""
            SELECT COUNT(*) FROM history
            WHERE datetime(datetime_taken) >= datetime('now', '-7 days')
        """).fetchone()[0]
        
        container_stats = {row[0]: row[1] for row in by_container}
        
        logger.info(f"✅ Fetched history stats for device {device_id}")
        return {
            "total_entries": total,
            "by_container": container_stats,
            "recent_7_days": recent,
            "device_id": device_id
        }
    
    except Exception as e:
        logger.error(f"❌ Failed to fetch history stats for device {device_id}: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"❌ Failed to fetch history stats: {e}"
        )
    finally:
        conn.close()