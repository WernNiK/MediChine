from fastapi import APIRouter, Body
from context import firebase_config_store

router = APIRouter()

@router.post("/update_dispensing_message", summary="Update dispensing Pushbullet message")
def update_dispensing_message(
    dispensing_message: str = Body(..., embed=True),
):
    """
    Saves the custom 'dispensing_message' into memory (or your DB).
    """
    firebase_config_store["dispensing_message"] = dispensing_message
    return {"status": "ok"}
