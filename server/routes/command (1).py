from firebase import get_command_ref

def send_command(command_data: dict) -> bool:
    """
    Pushes full schedule command details into the Firebase queue under `/commands`.
    Expected format:
    {
        "container_id": int,
        "name": str,
        "days": list,
        "time": str,
        "quantity": int
    }
    Returns True on success, False on failure.
    """
    try:
        ref = get_command_ref().parent.child("commands")
        ref.push(command_data)
        print(f"📤 Pushed command data: {command_data}")
        return True

    except Exception as e:
        print(f"❌ Failed to push command data '{command_data}': {e}")
        return False
