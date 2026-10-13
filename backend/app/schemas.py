from typing import Literal

from pydantic import BaseModel, Field


class SensorReading(BaseModel):
    """One reading from the simulator or the ESP32 device."""

    sample_id: str = Field(min_length=1, max_length=80)
    temperature_c: float = Field(ge=-10, le=100)
    ph: float = Field(ge=0, le=14)
    conductivity_us_cm: float = Field(ge=0)
    turbidity_ntu: float = Field(ge=0)
    source: Literal["simulated", "esp32"] = "simulated"
