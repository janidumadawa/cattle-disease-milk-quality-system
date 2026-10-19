import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

import psycopg
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from psycopg.types.json import Jsonb


load_dotenv(Path(__file__).resolve().parents[1] / ".env")


app = FastAPI(
    title="MedFarm API",
    description="Shared API foundation for the MedFarm research project.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- Shared foundation endpoints ----------

@app.get("/")
def root():
    return {
        "message": "MedFarm API is running",
        "status": "online",
    }


@app.get("/api/v1/health")
def health():
    return {
        "status": "ok",
        "service": "medfarm-api",
    }


def get_db_connection():
    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        raise HTTPException(
            status_code=503,
            detail="Database configuration is not available.",
        )

    try:
        return psycopg.connect(
            database_url,
            connect_timeout=10,
        )
    except psycopg.Error as exc:
        raise HTTPException(
            status_code=503,
            detail="Database connection is unavailable.",
        ) from exc

# ---------- Sensor reading models ----------

class TemperatureReading(BaseModel):
    value: float = Field(ge=-55, le=125)
    source: Literal["DS18B20", "SIMULATED"]


class PHReading(BaseModel):
    value: float = Field(ge=0, le=14)
    source: Literal["PH_SENSOR", "SIMULATED"]


class ConductivityReading(BaseModel):
    value: float = Field(ge=0)
    source: Literal["EC_SENSOR", "SIMULATED"]


class TurbidityReading(BaseModel):
    value: float = Field(ge=0)
    source: Literal["TURBIDITY_SENSOR", "SIMULATED"]


class MilkSampleReadings(BaseModel):
    temperature_c: TemperatureReading
    ph: PHReading
    conductivity_us_cm: ConductivityReading
    turbidity_ntu: TurbidityReading


# ---------- Sample request model ----------

class MilkSampleRequest(BaseModel):
    sample_id: str = Field(min_length=1, max_length=64)
    measurement_duration_seconds: int = Field(ge=1, le=300)

    data_mode: Literal["MIXED", "SIMULATED", "REAL"]

    # Explicitly selected demo outcome.
    # This is NOT a machine-learning prediction.
    demo_scenario: Literal["PASS", "FAIL"] = "PASS"

    readings: MilkSampleReadings


class DeviceProgressUpdate(BaseModel):
    status: Literal["measuring", "error"]
    elapsed_seconds: int = Field(ge=0, le=15)
    remaining_seconds: int = Field(ge=0, le=15)
    temperature_c: float | None = Field(
        default=None,
        ge=-55,
        le=125,
    )
    message: str = ""

# ---------- Latest physical device sample ----------

_latest_device_sample: dict | None = None

_device_start_requested = False

_device_progress: dict = {
    "status": "idle",
    "duration_seconds": 15,
    "elapsed_seconds": 0,
    "remaining_seconds": 15,
    "temperature_c": None,
    "temperature_source": "DS18B20",
    "message": "Ready to start a sample.",
    "updated_at": datetime.now(timezone.utc).isoformat(),
}

# ---------- ESP32 measurement coordination ----------

@app.post("/api/v1/device/start")
def request_device_start():
    global _device_start_requested, _device_progress

    if _device_progress["status"] in {"requested", "measuring"}:
        return {
            "status": "busy",
            "message": "A measurement is already pending or running.",
            "progress": _device_progress,
        }

    _device_start_requested = True

    _device_progress = {
        "status": "requested",
        "duration_seconds": 15,
        "elapsed_seconds": 0,
        "remaining_seconds": 15,
        "temperature_c": None,
        "temperature_source": "DS18B20",
        "message": "Waiting for the ESP32 to start measuring.",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    return {
        "status": "requested",
        "message": "Measurement request queued for the ESP32.",
        "progress": _device_progress,
    }


@app.get("/api/v1/device/command")
def get_device_command():
    global _device_start_requested

    start_requested = _device_start_requested

    # A start command is delivered only once.
    if start_requested:
        _device_start_requested = False

    return {
        "start_requested": start_requested,
        "duration_seconds": 15,
    }


@app.post("/api/v1/device/progress")
def update_device_progress(update: DeviceProgressUpdate):
    global _device_progress

    _device_progress = {
        "status": update.status,
        "duration_seconds": 15,
        "elapsed_seconds": update.elapsed_seconds,
        "remaining_seconds": update.remaining_seconds,
        "temperature_c": update.temperature_c,
        "temperature_source": (
            "DS18B20" if update.temperature_c is not None else None
        ),
        "message": update.message,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    return {
        "status": "ok",
        "progress": _device_progress,
    }


@app.get("/api/v1/device/progress")
def get_device_progress():
    return _device_progress


# ---------- Milk-quality endpoint ----------

@app.post("/api/v1/milk-samples")
def receive_milk_sample(sample: MilkSampleRequest):
    global _latest_device_sample, _device_progress

    received_at_dt = datetime.now(timezone.utc)
    received_at = received_at_dt.isoformat()

    response_data = {
        "status": "received",
        "message": "Sample received and validated.",
        "sample_id": sample.sample_id,
        "measurement_duration_seconds":
            sample.measurement_duration_seconds,
        "data_mode": sample.data_mode,
        "received_at": received_at,
        "readings": sample.readings.model_dump(),
        "classification": {
            "result": sample.demo_scenario,
            "status": "DEMO_ONLY",
            "research_validated": False,
            "explanation": (
                "The outcome was explicitly selected for the "
                "demonstration. It is not an ML prediction."
            ),
        },
    }

    readings = sample.readings

    # Persist every submitted sample, including clearly labelled
    # simulated/demo samples, for traceability.
    try:
        with get_db_connection() as conn:
            conn.execute(
                """
                INSERT INTO milk_samples (
                    sample_id,
                    received_at,
                    measurement_duration_seconds,
                    data_mode,
                    demo_scenario,
                    temperature_c,
                    temperature_source,
                    ph,
                    ph_source,
                    conductivity_us_cm,
                    conductivity_source,
                    turbidity_ntu,
                    turbidity_source,
                    classification_result,
                    classification_status,
                    research_validated,
                    response_payload
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s
                )
                """,
                (
                    sample.sample_id,
                    received_at_dt,
                    sample.measurement_duration_seconds,
                    sample.data_mode,
                    sample.demo_scenario,
                    readings.temperature_c.value,
                    readings.temperature_c.source,
                    readings.ph.value,
                    readings.ph.source,
                    readings.conductivity_us_cm.value,
                    readings.conductivity_us_cm.source,
                    readings.turbidity_ntu.value,
                    readings.turbidity_ntu.source,
                    sample.demo_scenario,
                    "DEMO_ONLY",
                    False,
                    Jsonb(response_data),
                ),
            )

    except psycopg.errors.UniqueViolation as exc:
        raise HTTPException(
            status_code=409,
            detail="A sample with this sample_id already exists.",
        ) from exc
    except psycopg.Error as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not save the sample to the database.",
        ) from exc

    # Keep the existing in-memory state for the live measurement UI.
    if readings.temperature_c.source == "DS18B20":
        _latest_device_sample = response_data

        _device_progress = {
            "status": "completed",
            "duration_seconds":
                sample.measurement_duration_seconds,
            "elapsed_seconds":
                sample.measurement_duration_seconds,
            "remaining_seconds": 0,
            "temperature_c": readings.temperature_c.value,
            "temperature_source": "DS18B20",
            "message": "Sample measurement completed.",
            "updated_at": received_at,
        }

    return response_data


# ---------- Milk sample history endpoint ----------

@app.get("/api/v1/milk-samples")
def list_milk_samples(
    limit: int = Query(default=20, ge=1, le=100),
):
    try:
        with get_db_connection() as conn:
            rows = conn.execute(
                """
                SELECT response_payload
                FROM milk_samples
                ORDER BY received_at DESC
                LIMIT %s
                """,
                (limit,),
            ).fetchall()

    except psycopg.Error as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve milk sample history.",
        ) from exc

    return {
        "status": "ok",
        "count": len(rows),
        "samples": [row[0] for row in rows],
    }

# ---------- Latest physical device sample endpoint ----------

@app.get("/api/v1/milk-samples/latest")
def get_latest_device_sample():
    try:
        with get_db_connection() as conn:
            row = conn.execute(
                """
                SELECT response_payload
                FROM milk_samples
                WHERE temperature_source = %s
                ORDER BY received_at DESC
                LIMIT 1
                """,
                ("DS18B20",),
            ).fetchone()

    except psycopg.Error as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve the latest device sample.",
        ) from exc

    if row is None:
        return {
            "status": "empty",
            "message": "No ESP32 temperature sample received yet.",
        }

    return {
        "status": "ok",
        "sample": row[0],
    }
