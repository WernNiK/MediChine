import pytz

selected_timezone = pytz.timezone("Asia/Manila")
# Stores the Firebase config received from the Flutter QR scan
firebase_config_store = {}


# Tracks whether QR config has been received (wrapped in dict for mutability)
qr_state = {"received": False}

def set_selected_timezone(tz_name: str):
    global selected_timezone
    try:
        selected_timezone = pytz.timezone(tz_name)
        print(f"🌐 Timezone updated to: {tz_name}")
    except pytz.UnknownTimeZoneError:
        print(f"❌ Invalid timezone: {tz_name}, keeping previous timezone.")