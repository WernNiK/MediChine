from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from history.history_writer import save_history_record
from context import firebase_config_store
from routes.notification import send_taken_notification

router = APIRouter()

class HistoryRecord(BaseModel):
    medicine_name: str
    container_id: int
    quantity: int
    scheduled_time: str
    scheduled_days: str
    datetime_taken: str
    time_taken: str

@router.post("/push_history", summary="Receive complete history data from ESP32")
def push_history(record: HistoryRecord):
    device_id = firebase_config_store.get("device_id")
    if not device_id:
        print("❌ No device_id found in firebase_config_store.")
        return {"error": "❌ Device not registered"}

    print(f"📥 Received complete history from ESP32:")
    print(f"   Medicine: {record.medicine_name}")
    print(f"   Container: {record.container_id}")
    print(f"   Quantity: {record.quantity}")
    print(f"   Scheduled: {record.scheduled_time} on {record.scheduled_days}")
    print(f"   Taken: {record.time_taken} ({record.datetime_taken})")

    try:
        send_taken_notification(record.container_id, record.medicine_name, record.time_taken)
    except Exception as e:
        print(f"⚠️ Failed to send notification: {e}")

    save_history_record(
        device_id=device_id,
        medicine_name=record.medicine_name,
        container_id=record.container_id,
        quantity=record.quantity,
        scheduled_time=record.scheduled_time,
        scheduled_days=record.scheduled_days,
        datetime_taken=record.datetime_taken,
        time_taken=record.time_taken
    )

    return {
        "status": "✅ History saved successfully",
        "medicine_name": record.medicine_name,
        "container_id": record.container_id,
        "quantity": record.quantity
    }