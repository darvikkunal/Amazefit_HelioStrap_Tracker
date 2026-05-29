from fastapi import FastAPI, UploadFile, File
import sqlite3
import zipfile
import tempfile
import os

app = FastAPI()

def get_value(cursor, sql):
    try:
        cursor.execute(sql)
        row = cursor.fetchone()
        return row[0] if row else None
    except:
        return None

@app.post("/extract")
async def extract(zip_file: UploadFile = File(...)):

    with tempfile.TemporaryDirectory() as tmpdir:

        zip_path = os.path.join(tmpdir, "health.zip")

        with open(zip_path, "wb") as f:
            f.write(await zip_file.read())

        with zipfile.ZipFile(zip_path, "r") as z:
            z.extractall(tmpdir)

        db_path = None

        for root, dirs, files in os.walk(tmpdir):
            for file in files:
                if file.endswith(".db"):
                    db_path = os.path.join(root, file)
                    break

        if not db_path:
            return {"error": "No DB file found"}

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        results = {}

        queries = {
            "steps": """
            SELECT SUM(count)
            FROM steps_record_table
            WHERE local_date =
            (SELECT MAX(local_date)
             FROM steps_record_table)
            """,

            "resting_hr": """
            SELECT ROUND(AVG(beats_per_minute),0)
            FROM resting_heart_rate_record_table
            WHERE local_date =
            (SELECT MAX(local_date)
             FROM resting_heart_rate_record_table)
            """,

            "hrv_avg": """
            SELECT ROUND(
                AVG(heart_rate_variability_millis),1
            )
            FROM heart_rate_variability_rmssd_record_table
            WHERE local_date =
            (
              SELECT MAX(local_date)
              FROM heart_rate_variability_rmssd_record_table
            )
            """,

            "spo2_avg": """
            SELECT ROUND(AVG(percentage),1)
            FROM oxygen_saturation_record_table
            WHERE local_date =
            (
              SELECT MAX(local_date)
              FROM oxygen_saturation_record_table
            )
            """,

            "distance_km": """
            SELECT ROUND(
                SUM(distance)/1000.0,2
            )
            FROM distance_record_table
            WHERE local_date =
            (
              SELECT MAX(local_date)
              FROM distance_record_table
            )
            """,

            "calories": """
            SELECT ROUND(
                SUM(energy)/1000.0,0
            )
            FROM total_calories_burned_record_table
            WHERE local_date =
            (
              SELECT MAX(local_date)
              FROM total_calories_burned_record_table
            )
            """
        }

        for key, sql in queries.items():
            results[key] = get_value(cur, sql)

        conn.close()

        return results
