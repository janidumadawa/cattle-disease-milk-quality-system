from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timezone
from typing import Literal

from fastapi import FastAPI
from pydantic import BaseModel, Field


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

    received_at = datetime.now(timezone.utc).isoformat()

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

    if sample.readings.temperature_c.source == "DS18B20":
        _latest_device_sample = response_data

        _device_progress = {
            "status": "completed",
            "duration_seconds":
                sample.measurement_duration_seconds,
            "elapsed_seconds":
                sample.measurement_duration_seconds,
            "remaining_seconds": 0,
            "temperature_c":
                sample.readings.temperature_c.value,
            "temperature_source": "DS18B20",
            "message": "Sample measurement completed.",
            "updated_at": received_at,
        }

    return response_data

# ---------- Latest device sample endpoint ----------

@app.get("/api/v1/milk-samples/latest")
def get_latest_device_sample():
    if _latest_device_sample is None:
        return {
            "status": "empty",
            "message": "No ESP32 temperature sample received yet.",
        }

    return {
        "status": "ok",
        "sample": _latest_device_sample,
    }