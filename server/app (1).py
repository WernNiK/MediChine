from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from routes import schedules, testing
from routes.matched import trigger_match_schedule, set_selected_timezone, set_firebase_ready
from routes import device_management
from pydantic import BaseModel, field_validator
from firebase import initialize_firebase, is_firebase_initialized
from database import init_device_db, get_device_db_path
from context import firebase_config_store, qr_state
from routes import configure
from history import push_history, history_api
from history.history import init_history_db
import device_registry
import re
import os
import json
from typing import Callable

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Simple email validation regex
EMAIL_REGEX = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')

# ✅ FIXED: Separate device endpoints from app endpoints
class DeviceAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # List of endpoints that don't require email validation
        public_endpoints = [
            "/",
            "/docs",
            "/openapi.json",
            "/health",
            "/system_status",
            "/register_firebase",
            "/firebase_config",
            "/reset_system",
            "/device/check_access",
            "/device/verify_ownership",
        ]
        
        # ✅ NEW: Device-only endpoints (ESP32 calls - no email needed)
        device_only_endpoints = [
            "/push_history",  # ESP32 logs medicine taken here
            "/test_command",  # ESP32 can receive test commands
        ]
        
        # Check if the path is public or device-only
        path = request.url.path
        is_public = any(path == endpoint or path.startswith(endpoint + "/") for endpoint in public_endpoints)
        is_device_only = any(path == endpoint or path.startswith(endpoint + "/") for endpoint in device_only_endpoints)
        
        print(f"🔒 Middleware check: {request.method} {path} | Public: {is_public} | Device-only: {is_device_only}")
        
        # Skip email validation for public and device-only endpoints
        if is_public or is_device_only:
            if is_device_only:
                print(f"✅ Device-only endpoint - no email validation required")
            return await call_next(request)
        
        # For all other endpoints, validate email
        if not firebase_config_store or "device_id" not in firebase_config_store:
            print("⚠️ No device configured yet - allowing request")
            return await call_next(request)
        
        device_id = firebase_config_store.get("device_id")
        owner_email = firebase_config_store.get("owner_email")
        
        print(f"🔐 Device: {device_id} | Owner: {owner_email}")
        
        if device_id:
            # Check if device is still active
            is_registered = device_registry.is_device_registered(device_id)
            
            if not is_registered:
                print("❌ Device not registered")
                raise HTTPException(
                    status_code=403,
                    detail="Device is disconnected. Please reconnect by scanning the QR code."
                )
            
            # Verify ownership matches
            current_owner = device_registry.get_device_owner(device_id)
            if owner_email and current_owner != owner_email:
                print(f"❌ Ownership mismatch: {current_owner} vs {owner_email}")
                raise HTTPException(
                    status_code=403,
                    detail="Device ownership has changed. Please reconnect."
                )
            
            # ✅ Extract email from request (only for app endpoints)
            request_email = None
            
            # 1. Check query parameters
            if "email" in request.query_params:
                request_email = request.query_params.get("email", "").lower().strip()
                print(f"📧 Email from query params: {request_email}")
            
            # 2. Check POST/PUT/PATCH body
            if not request_email and request.method in ["POST", "PUT", "PATCH"]:
                try:
                    body = await request.body()
                    if body:
                        try:
                            data = json.loads(body)
                            request_email = (data.get("email") or data.get("owner_email", "")).lower().strip()
                            print(f"📧 Email from body: {request_email}")
                        except json.JSONDecodeError:
                            print("⚠️ Failed to parse JSON body")
                        
                        # Reset the body for route handlers
                        async def receive():
                            return {"type": "http.request", "body": body}
                        request._receive = receive
                except Exception as e:
                    print(f"⚠️ Error reading body: {e}")
            
            # ✅ VALIDATE EMAIL (only for non-device endpoints)
            if request_email:
                # Validate format
                if not EMAIL_REGEX.match(request_email):
                    print(f"❌ Invalid email format: {request_email}")
                    raise HTTPException(
                        status_code=400,
                        detail="Invalid email format"
                    )
                
                # Check ownership
                if request_email != current_owner:
                    masked_owner = current_owner[:3] + "***@" + current_owner.split('@')[1]
                    print(f"❌ UNAUTHORIZED: {request_email} trying to access {masked_owner}'s device")
                    
                    # Return proper JSON response instead of raising exception
                    from fastapi.responses import JSONResponse
                    return JSONResponse(
                        status_code=403,
                        content={
                            "detail": f"Access denied: This device is registered to {masked_owner}",
                            "error_code": "UNAUTHORIZED_ACCESS",
                            "device_owner": masked_owner
                        }
                    )
                
                print(f"✅ Authorized: {request_email}")
            else:
                print("❌ No email provided in request")
                raise HTTPException(
                    status_code=400,
                    detail="Email parameter is required for this operation"
                )
        
        response = await call_next(request)
        return response

# ✅ IMPORTANT: Add middleware BEFORE including routers
app.add_middleware(DeviceAuthMiddleware)

@app.on_event("startup")
def on_startup():
    print("🚀 MediChine API starting up...")
    print("📱 Initializing device registry database...")
    device_registry.init_registry_db()
    print("📱 Waiting for QR code configuration...")
    print("⚠️  Firebase will be initialized after QR code is scanned and sent to /register_firebase")
    trigger_match_schedule()

# ✅ Include routers AFTER middleware
app.include_router(schedules.router)
app.include_router(testing.router)
app.include_router(configure.router)
app.include_router(push_history.router)
app.include_router(history_api.router)
app.include_router(device_management.router)

@app.get("/")
def root():
    firebase_status = "✅ Ready" if is_firebase_initialized() else "⏳ Waiting for QR code"
    return {
        "message": "✅ MediChine API is running",
        "firebase_status": firebase_status,
        "qr_config_received": qr_state["received"]
    }

class TimezoneRequest(BaseModel):
    timezone: str
    email: str
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError('Invalid email format')
        return v.lower()

@app.post("/update_timezone")
def update_timezone(req: TimezoneRequest):
    try:
        set_selected_timezone(req.timezone)
        return {"message": f"Timezone set to {req.timezone}"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

class FirebaseConfig(BaseModel):
    firebase_url: str
    device_id: str
    auth_token: str
    owner_email: str
    
    @field_validator('owner_email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not EMAIL_REGEX.match(v):
            raise ValueError('Invalid email format')
        return v.lower()

@app.post("/register_firebase")
def register_firebase(config: FirebaseConfig):
    try:
        print("📱 Received Firebase config from Flutter app (QR code scan)")

        if not config.firebase_url or not config.device_id or not config.auth_token or not config.owner_email:
            raise HTTPException(status_code=400, detail="Missing Firebase config fields from QR code.")
        
        if not config.firebase_url.startswith("https://"):
            raise HTTPException(status_code=400, detail="Invalid Firebase URL from QR code. Must start with 'https://'")

        # Check device access and register
        registration_result = device_registry.register_device(
            config.device_id, 
            config.owner_email, 
            config.firebase_url
        )
        
        if not registration_result["success"]:
            raise HTTPException(
                status_code=403,
                detail=registration_result["message"]
            )

        firebase_config_store.clear()
        firebase_config_store.update({
            "firebase_url": config.firebase_url,
            "device_id": config.device_id,
            "auth_token": config.auth_token,
            "owner_email": config.owner_email
        })

        init_device_db(config.device_id, config.firebase_url, config.auth_token)
        initialize_firebase(firebase_url=config.firebase_url)
        init_history_db(config.device_id)

        qr_state["received"] = True
        set_firebase_ready(True)
        
        device_registry.update_last_connected(config.device_id)

        print(f"✅ Device registered: {config.device_id} -> {config.owner_email}")

        return {
            "message": f"✅ {registration_result['message']}. Firebase initialized and history synced.",
            "device_id": config.device_id,
            "firebase_url": config.firebase_url,
            "owner_email": config.owner_email[:3] + "***@" + config.owner_email.split('@')[1],
            "action": registration_result.get("action", "registered")
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Failed to initialize Firebase from QR code: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to initialize Firebase from QR code: {e}")

@app.get("/firebase_config")
def get_firebase_config():
    if not firebase_config_store:
        raise HTTPException(
            status_code=404, 
            detail="No Firebase config found. Please scan QR code with Flutter app first."
        )
    
    safe_config = firebase_config_store.copy()
    if "auth_token" in safe_config:
        token = safe_config["auth_token"]
        safe_config["auth_token"] = ('*' * (len(token) - 4) + token[-4:] if len(token) > 4 else '****')
    
    if "owner_email" in safe_config:
        email = safe_config["owner_email"]
        safe_config["owner_email"] = email[:3] + "***@" + email.split('@')[1]

    return {
        "config": safe_config,
        "qr_config_received": qr_state["received"],
        "firebase_initialized": is_firebase_initialized()
    }

@app.get("/system_status")
def system_status():
    # Check if device is active
    device_active = False
    device_owner = None
    if firebase_config_store and "device_id" in firebase_config_store:
        device_id = firebase_config_store.get("device_id")
        device_active = device_registry.is_device_registered(device_id) if device_id else False
        if device_active:
            device_owner = device_registry.get_device_owner(device_id)
    
    return {
        "api_running": True,
        "qr_config_received": qr_state["received"],
        "firebase_initialized": is_firebase_initialized(),
        "firebase_config_available": bool(firebase_config_store),
        "device_registry_active": True,
        "device_connected": device_active,
        "device_owner": device_owner[:3] + "***@" + device_owner.split('@')[1] if device_owner else None,
        "next_step": (
            "✅ System ready" if is_firebase_initialized() and device_active
            else "📱 Please scan QR code to /register_firebase"
        )
    }

@app.post("/reset_system")
def reset_system():
    try:
        from firebase import reset_firebase
        reset_firebase()
        qr_state["received"] = False
        firebase_config_store.clear()
        firebase_config_store.update({})
        set_firebase_ready(False)

        return {
            "message": "✅ System reset complete. Please scan QR code again.",
            "qr_config_received": False,
            "firebase_initialized": False
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to reset system: {e}")

@app.get("/health")
def health_check():
    # Check device connection status
    device_status = "❌ Not connected"
    device_owner = None
    if firebase_config_store and "device_id" in firebase_config_store:
        device_id = firebase_config_store.get("device_id")
        if device_id and device_registry.is_device_registered(device_id):
            device_status = "✅ Connected"
            device_owner = device_registry.get_device_owner(device_id)
        elif device_id:
            device_status = "⚠️ Disconnected"
    
    return {
        "status": "healthy",
        "timestamp": __import__("datetime").datetime.now().isoformat(),
        "components": {
            "api": "✅ Running",
            "database": "✅ Connected",
            "device_registry": "✅ Active",
            "device_connection": device_status,
            "device_owner": device_owner[:3] + "***@" + device_owner.split('@')[1] if device_owner else None,
            "qr_config": "✅ Received" if qr_state["received"] else "⏳ Waiting",
            "firebase": "✅ Initialized" if is_firebase_initialized() else "❌ Not initialized",
            "scheduler": "✅ Running"
        },
        "ready_for_commands": is_firebase_initialized() and device_status == "✅ Connected"
    }