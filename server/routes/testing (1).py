from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, field_validator
from routes.command import send_command
from routes.matched import get_dispensing_status
from firebase import is_firebase_initialized
import routes.matched as matched
import re

router = APIRouter()

# Email validation regex
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

# ✅ Updated request model with email
class TestCommandRequest(BaseModel):
    email: str  # ✅ Required
    container_id: int
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError('Invalid email format')
        return v.lower()

@router.post("/test_command")
def test_command(request: TestCommandRequest):
    """
    Send test command to a container - email validated by middleware
    """
    if not matched.firebase_ready:
        raise HTTPException(
            status_code=400,
            detail="❌ Cannot send commands: Please scan QR code with Flutter app first and send configuration to /register_firebase"
        )
    
    if not is_firebase_initialized():
        raise HTTPException(
            status_code=503,
            detail="❌ Firebase configuration received but not initialized properly. Please try /register_firebase again."
        )
    
    command_map = {
        1: "command1",
        2: "command2",
        3: "command3",
        4: "command4"
    }
    
    if request.container_id not in command_map:
        raise HTTPException(
            status_code=400, 
            detail="Invalid container ID. Must be 1, 2, 3, or 4."
        )
    
    command = command_map[request.container_id]
    
    # Send command as dictionary with container_id
    command_data = {
        "container_id": request.container_id,
        "name": f"Test Container {request.container_id}",
        "days": [],
        "time": "",
        "quantity": 1
    }
    
    if send_command(command_data):
        return {
            "message": f"✅ Test command sent to container {request.container_id}",
            "container_id": request.container_id
        }
    else:
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to send test command to container {request.container_id}"
        )

@router.get("/test_firebase_status")
def test_firebase_status(email: str):
    """
    Get Firebase and system status - email required as query parameter
    """
    status = {
        "qr_config_received": matched.firebase_ready,
        "firebase_initialized": is_firebase_initialized(),
        **get_dispensing_status()
    }
    
    if not status["qr_config_received"]:
        status["message"] = "📱 Please scan QR code with Flutter app and send to /register_firebase"
    elif not status["firebase_initialized"]:
        status["message"] = "⚠️ QR code received but Firebase not initialized properly"
    else:
        status["message"] = "✅ System ready for commands"
    
    return status

@router.post("/test_firebase_init")
def test_firebase_init(email: str):
    """
    Test Firebase initialization status - email required as query parameter
    """
    if matched.firebase_ready and is_firebase_initialized():
        return {
            "message": "✅ Firebase is already initialized from QR code",
            "status": "ready"
        }
    elif matched.firebase_ready:
        return {
            "message": "⚠️ QR code configuration received but Firebase not initialized. Please try scanning QR code again.",
            "action": "POST to /register_firebase with QR code data",
            "status": "partial"
        }
    else:
        return {
            "message": "📱 Please scan QR code with Flutter app first",
            "action": "Scan QR code and send configuration to /register_firebase",
            "status": "waiting_for_qr_code"
        }