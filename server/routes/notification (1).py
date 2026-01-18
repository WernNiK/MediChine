import requests
import logging
from typing import Optional
from context import firebase_config_store
from datetime import datetime
from context import selected_timezone

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PUSHBULLET_TOKEN = "o.ZTRMg7u9eNV6yxD1lvx7gegOUhVvrlRA"

PUSHBULLET_API_URL = "https://api.pushbullet.com/v2/pushes"
REQUEST_TIMEOUT = 10 

def send_dispensing_notification(container_id: int, default_msg: str) -> bool:
    if not isinstance(container_id, int) or container_id <= 0:
        logger.error(f"❌ Invalid container_id: {container_id}")
        return False

    if not default_msg or not default_msg.strip():
        logger.error("❌ Default message cannot be empty")
        return False

    device_id = firebase_config_store.get("device_id")
    if not device_id:
        logger.warning("❌ No device_id registered — skipping notification.")
        return False

    title = f"Dispensing on container {container_id}\n"
    custom_message = firebase_config_store.get("dispensing_message", default_msg)
    timestamp = datetime.now(selected_timezone).strftime("%d/%m/%Y %I:%M %p")

    body = f"Message: {custom_message}\n\n\nTime: {timestamp}"

    try:
        resp = requests.post(
            PUSHBULLET_API_URL,
            headers={
                "Access-Token": PUSHBULLET_TOKEN,
                "Content-Type": "application/json"
            },
            json={
                "type": "note",
                "title": title,
                "body": body
            },
            timeout=REQUEST_TIMEOUT
        )

        if resp.status_code == 200:
            logger.info(f"✅ Notification sent successfully!")
            logger.info(f"   📱 Device: {device_id}")
            logger.info(f"   💊 Container: {container_id}")
            logger.info(f"   📝 Title: {title}")
            return True
        else:
            logger.error(f"❌ Pushbullet API error [{resp.status_code}]: {resp.text}")
            return False

    except requests.exceptions.Timeout:
        logger.error(f"❌ Pushbullet request timeout after {REQUEST_TIMEOUT}s")
        return False
    except requests.exceptions.ConnectionError:
        logger.error("❌ Connection error - check internet connection")
        return False
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ Request failed: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"❌ Unexpected error: {str(e)}")
        return False

def send_taken_notification(container_id: int, medicine_name: str, time_taken: str) -> bool:
    """Send push notification when medicine is taken"""
    device_id = firebase_config_store.get("device_id")
    if not device_id:
        logger.warning("❌ No device_id registered — skipping taken notification.")
        return False
    
    if not PUSHBULLET_TOKEN:
        logger.warning("❌ No Pushbullet token configured — skipping notification.")
        return False

    title = "Medicine has been taken\n"
    default_msg = "Your medicine has been taken by the patient successfully."
    custom_message = firebase_config_store.get("dispensing_message", default_msg)
    
    body = f"Medicine: {medicine_name}\n"
    body += f"Container: {container_id}\n"
    body += f"Message: {custom_message}\n\n"
    body += f"Time: {time_taken}"

    try:
        resp = requests.post(
            PUSHBULLET_API_URL,
            headers={
                "Access-Token": PUSHBULLET_TOKEN,
                "Content-Type": "application/json"
            },
            json={
                "type": "note",
                "title": title,
                "body": body
            },
            timeout=REQUEST_TIMEOUT
        )
        
        if resp.status_code == 200:
            logger.info(f"✅ Taken notification sent for {medicine_name} from container {container_id} at {time_taken}")
            return True
        else:
            logger.error(f"❌ Taken notification failed [{resp.status_code}]: {resp.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Failed to send taken notification: {str(e)}")
        return False

def send_error_notification(container_id: int, error_msg: str) -> bool:
    """Send push notification when there's an error"""
    device_id = firebase_config_store.get("device_id", "Unknown")
    
    if not PUSHBULLET_TOKEN:
        logger.warning("❌ No Pushbullet token configured — skipping error notification.")
        return False
    
    title = f"🚨 Dispensing Error - Container {container_id}"
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    body = f"⚠️ ERROR: {error_msg}\n\n"
    body += f"💊 Container: {container_id}\n"
    body += f"🕒 Time: {timestamp}\n"
    body += f"📱 Device: {device_id}\n\n"
    body += "Please check your medicine dispenser!"

    try:
        resp = requests.post(
            PUSHBULLET_API_URL,
            headers={
                "Access-Token": PUSHBULLET_TOKEN,
                "Content-Type": "application/json"
            },
            json={
                "type": "note",
                "title": title,
                "body": body
            },
            timeout=REQUEST_TIMEOUT
        )
        
        if resp.status_code == 200:
            logger.info(f"✅ Error notification sent for container {container_id}")
            return True
        else:
            logger.error(f"❌ Error notification failed [{resp.status_code}]: {resp.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Failed to send error notification: {str(e)}")
        return False

def test_notification() -> bool:
    try:
        resp = requests.get(
            "https://api.pushbullet.com/v2/users/me",
            headers={"Access-Token": PUSHBULLET_TOKEN},
            timeout=REQUEST_TIMEOUT
        )

        if resp.status_code == 200:
            user_data = resp.json()
            logger.info(f"✅ Pushbullet connection OK - User: {user_data.get('name', 'Unknown')}")
            return True
        else:
            logger.error(f"❌ Pushbullet test failed [{resp.status_code}]: {resp.text}")
            return False
    except Exception as e:
        logger.error(f"❌ Pushbullet test error: {str(e)}")
        return False

# Example usage
if __name__ == "__main__":
    print("🧪 Testing notification system...")
    
    if test_notification():
        success = send_dispensing_notification(1, "Your medicine has been dispensed successfully!")
        print(f"Dispensing notification test: {'✅ PASSED' if success else '❌ FAILED'}")
        
        success = send_error_notification(1, "Servo motor not responding")
        print(f"Error notification test: {'✅ PASSED' if success else '❌ FAILED'}")
    else:
        print("❌ Connection test failed - check your token.")
