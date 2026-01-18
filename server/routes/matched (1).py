import datetime
import time
import threading
import sqlite3
import pytz
from firebase import is_firebase_initialized
from database import get_db_connection_for_device, close_db_connection
from context import selected_timezone, set_selected_timezone, firebase_config_store
from fastapi import HTTPException
from routes.command import send_command
from routes.notification import send_dispensing_notification

triggered_schedules = {}
schedule_thread_started = False
is_dispensing = False
firebase_ready = False

def set_firebase_ready(ready: bool):
    """
    Sets the Firebase ready status. Called when QR code config is received.
    """
    global firebase_ready
    firebase_ready = ready
    if ready:
        print("🔥 Firebase is now ready for commands!")
    else:
        print("⏳ Firebase not ready - waiting for QR code configuration...")

def get_device_conn():
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

def match_schedule():
    global triggered_schedules, is_dispensing

    last_checked_minute = None

    while True:
        try:
            now = datetime.datetime.now(selected_timezone)
            current_minute = now.strftime("%Y-%m-%d %H:%M")

            if current_minute == last_checked_minute:
                time.sleep(1)
                continue

            last_checked_minute = current_minute

            if is_dispensing:
                time.sleep(1)
                continue

            if not firebase_ready:
                time.sleep(10)
                continue
                
            if not is_firebase_initialized():
                time.sleep(10)
                continue

            current_time = now.strftime("%I:%M %p")
            current_day = now.strftime("%a")

            conn = get_device_conn()
            try:
                cursor = conn.execute(
                    "SELECT id, name, time, days, container_id, quantity FROM schedules"
                )
                schedules = cursor.fetchall()
                
                for sid, med_name, time_str, days_str, container_id, quantity in schedules:
                    try:
                        formatted = datetime.datetime.strptime(time_str, "%I:%M %p").strftime("%I:%M %p")
                        days_list = [d.strip().capitalize() for d in days_str.split(",")] if days_str else []
                        qty = int(quantity)
                    except Exception as e:
                        continue
                
                    if current_day in days_list and formatted == current_time:
                        if triggered_schedules.get(sid):
                            continue
                    
                        is_dispensing = True
                        command_data = {
                            "container_id": container_id,
                            "name": med_name,
                            "days": days_list,
                            "time": formatted,
                            "quantity": qty 
                        }
                        if send_command(command_data):
                            triggered_schedules[sid] = True
                            default_msg = "Time to take your medicine!"
                            send_dispensing_notification(container_id, default_msg)
                    
                        is_dispensing = False
            
            finally:
                close_db_connection(conn)

        except Exception:
            is_dispensing = False

        time.sleep(1)

def reset_triggered_schedules():
    global triggered_schedules
    while True:
        try:
            now = datetime.datetime.now(selected_timezone)
            if now.strftime("%H:%M") == "00:00":
                triggered_schedules = {}
        except Exception:
            pass
        time.sleep(60)

def trigger_match_schedule():
    global schedule_thread_started
    if not schedule_thread_started:
        threading.Thread(target=match_schedule, daemon=True).start()
        threading.Thread(target=reset_triggered_schedules, daemon=True).start()
        schedule_thread_started = True

def get_dispensing_status():
    """
    Returns the current dispensing status.
    """
    return {
        "is_dispensing": is_dispensing,
        "firebase_ready": firebase_ready,
        "firebase_initialized": is_firebase_initialized(),
        "triggered_schedules_count": len(triggered_schedules),
        "status_message": (
            "✅ Ready for commands"
            if firebase_ready and is_firebase_initialized()
            else "📱 Waiting for QR code configuration"
            if not firebase_ready
            else "⚠️ Configuration received but Firebase not initialized"
        )
    }
