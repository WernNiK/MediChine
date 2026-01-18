"""
Device Management Routes
API endpoints for device registration and management
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, field_validator
from typing import List, Dict
import device_registry as registry
import re

router = APIRouter(prefix="/device", tags=["Device Management"])

# Simple email validation regex
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

class DeviceDisconnectRequest(BaseModel):
    device_id: str
    owner_email: str
    
    @field_validator('owner_email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError('Invalid email format')
        return v.lower()

class DeviceCheckRequest(BaseModel):
    device_id: str
    email: str
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError('Invalid email format')
        return v.lower()

@router.post("/disconnect")
def disconnect_device(request: DeviceDisconnectRequest):
    """
    Disconnect a device from a user account
    """
    try:
        result = registry.disconnect_device(request.device_id, request.owner_email)
        
        if not result["success"]:
            raise HTTPException(
                status_code=403 if result.get("error_code") == "NOT_OWNER" else 404,
                detail=result["message"]
            )
        
        # NEW: Clear server config if this is the currently connected device
        from context import firebase_config_store, qr_state
        from routes.matched import set_firebase_ready
        
        if firebase_config_store.get("device_id") == request.device_id:
            print(f"🔌 Clearing server config for disconnected device: {request.device_id}")
            firebase_config_store.clear()
            firebase_config_store.update({})
            qr_state["received"] = False
            set_firebase_ready(False)
            
            # Reset Firebase connection
            try:
                from firebase import reset_firebase
                reset_firebase()
                print("✅ Firebase connection reset")
            except Exception as e:
                print(f"⚠️ Failed to reset Firebase: {e}")
        
        return {
            "message": result["message"],
            "device_id": request.device_id,
            "server_config_cleared": firebase_config_store.get("device_id") != request.device_id
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to disconnect device: {str(e)}")

@router.post("/check_access")
def check_device_access(request: DeviceCheckRequest):
    """
    Check if a user can access a device
    Used before allowing QR code connection
    """
    try:
        # Check if device is already registered
        is_registered = registry.is_device_registered(request.device_id)
        
        if not is_registered:
            # Device is available
            return {
                "access_granted": True,
                "message": "Device is available for registration",
                "status": "available"
            }
        
        # Check ownership
        owner = registry.get_device_owner(request.device_id)
        
        if owner == request.email:
            # User owns this device
            return {
                "access_granted": True,
                "message": "You own this device",
                "status": "owned"
            }
        else:
            # Device is owned by someone else
            return {
                "access_granted": False,
                "message": "This device is already registered to another account",
                "status": "occupied",
                "error_code": "DEVICE_ALREADY_REGISTERED"
            }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to check device access: {str(e)}")

@router.get("/list/{email}")
def list_user_devices(email: str):
    """
    Get all devices registered to a user
    """
    try:
        devices = registry.get_user_devices(email)
        return {
            "email": email,
            "device_count": len(devices),
            "devices": devices
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve devices: {str(e)}")

@router.get("/info/{device_id}")
def get_device_info(device_id: str):
    """
    Get information about a specific device
    """
    try:
        info = registry.get_device_info(device_id)
        
        if not info:
            raise HTTPException(status_code=404, detail="Device not found or inactive")
        
        # Don't expose full email in public API
        info['owner_email'] = info['owner_email'][:3] + "***@" + info['owner_email'].split('@')[1]
        
        return info
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get device info: {str(e)}")

@router.post("/verify_ownership")
def verify_device_ownership(request: DeviceCheckRequest):
    """
    Verify if a user owns a specific device
    """
    try:
        owner = registry.get_device_owner(request.device_id)
        
        if not owner:
            return {
                "is_owner": False,
                "message": "Device not found or inactive"
            }
        
        is_owner = owner == request.email
        
        return {
            "is_owner": is_owner,
            "device_id": request.device_id,
            "message": "Ownership verified" if is_owner else "Not the owner"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to verify ownership: {str(e)}")

@router.get("/connection_history/{device_id}")
def get_connection_history(device_id: str, limit: int = 10):
    """
    Get connection history for a device (for debugging/audit)
    """
    try:
        from device_registry import get_db_connection
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """SELECT action, email, timestamp, success, notes
                   FROM connection_history
                   WHERE device_id = ?
                   ORDER BY timestamp DESC
                   LIMIT ?""",
                (device_id, limit)
            )
            
            history = []
            for row in cursor.fetchall():
                history.append({
                    "action": row['action'],
                    "email": row['email'][:3] + "***@" + row['email'].split('@')[1],
                    "timestamp": row['timestamp'],
                    "success": bool(row['success']),
                    "notes": row['notes']
                })
            
            return {
                "device_id": device_id,
                "history": history
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get connection history: {str(e)}")

@router.post("/admin/cleanup")
def cleanup_old_devices(days: int = 90, admin_key: str = ""):
    """
    Admin endpoint to clean up old inactive devices
    Requires admin authentication key
    """
    # TODO: Implement proper admin authentication
    if admin_key != "your_admin_key_here":  # Replace with actual auth
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    try:
        deleted = registry.cleanup_old_connections(days)
        return {
            "message": f"Cleaned up {deleted} old device registrations",
            "deleted_count": deleted
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cleanup failed: {str(e)}")