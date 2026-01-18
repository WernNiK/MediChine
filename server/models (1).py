from pydantic import BaseModel

class Schedule(BaseModel):
    container_id: int
    name: str
    time: str
    days: str
    quantity: int
