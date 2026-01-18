from history.history import get_history_db_connection
from database import get_db_connection_for_device

def get_schedule_history_matches(device_id: str):
    sched_conn = get_db_connection_for_device(device_id, "", "")
    hist_conn = get_history_db_connection(device_id)

    schedules = sched_conn.execute(
        "SELECT id, container_id, name, time, days, quantity FROM schedules"
    ).fetchall()

    history = hist_conn.execute(
        "SELECT container_id, datetime, scheduled_time, scheduled_days FROM history ORDER BY datetime ASC"
    ).fetchall()

    results = []
    used_history = set()

    for sched in schedules:
        sched_id, container_id, name, time, days_str, quantity = sched
        sched_days = set(d.strip().lower() for d in days_str.split(","))

        for hist in history:
            h_container_id, datetime_str, sched_time, hist_days_str = hist

            if datetime_str in used_history:
                continue 

            hist_days = set(d.strip().lower() for d in hist_days_str.split(","))

            if (
                container_id == h_container_id and
                time == sched_time and
                sched_days & hist_days
            ):
                results.append({
                    "name": name,
                    "days": days_str,
                    "time": time,
                    "quantity": quantity,
                    "time_taken": datetime_str
                })
                used_history.add(datetime_str)
                break

    sched_conn.close()
    hist_conn.close()
    return results
