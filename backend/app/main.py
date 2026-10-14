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


# ---------- Milk-quality endpoint ----------

@app.post("/api/v1/milk-samples")
def receive_milk_sample(sample: MilkSampleRequest):
    return {
        "status": "received",
        "message": "Sample received and validated.",
        "sample_id": sample.sample_id,
        "measurement_duration_seconds":
            sample.measurement_duration_seconds,
        "data_mode": sample.data_mode,
        "received_at": datetime.now(timezone.utc).isoformat(),
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