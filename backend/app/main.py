from datetime import datetime, timezone

from fastapi import FastAPI
from app.schemas import SensorReading

app = FastAPI(
    title="Cattle Disease & Milk Quality System API",
    description=(
        "Development API for raw-milk pre-screening readings. "
        "Database persistence will be added in a later step."
    ),
    version="0.1.0",
)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "name": "Milk Quality Pre-Screening API",
        "status": "online",
        "mode": "development",
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "online",
        "database": "not_configured",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/api/v1/readings")
def receive_reading(reading: SensorReading) -> dict:
    """Validate a sensor reading and return it; this does not save it yet."""
    return {
        "message": "Reading received. Persistence is not configured yet.",
        "received_at": datetime.now(timezone.utc).isoformat(),
        "reading": reading.model_dump(),
    }
