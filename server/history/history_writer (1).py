from history.history import get_history_db_connection, init_history_db

def save_history_record(device_id: str, medicine_name: str, container_id: int, quantity: int,
                       scheduled_time: str, scheduled_days: str, datetime_taken: str, time_taken: str):
    init_history_db(device_id)
    conn = get_history_db_connection(device_id)
    try:
        conn.execute("""
            INSERT INTO history 
            (medicine_name, container_id, quantity, scheduled_time, scheduled_days, datetime_taken, time_taken) 
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (medicine_name, container_id, quantity, scheduled_time, scheduled_days, datetime_taken, time_taken))
        conn.commit()
        print(f"✅ History saved: {medicine_name} from container {container_id} taken at {time_taken}")
    except Exception as e:
        print(f"❌ Failed to save history: {e}")
    finally:
        conn.close()