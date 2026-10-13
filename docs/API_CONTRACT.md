# Initial Sensor Readings API Contract

## Submit a reading

**Method:** `POST`  
**Path:** `/api/v1/readings`  
**Current status:** validates and echoes the request; database storage is not implemented yet.

Example request:

```json
{
  "sample_id": "DEMO-MILK-001",
  "temperature_c": 4.8,
  "ph": 6.7,
  "conductivity_us_cm": 850,
  "turbidity_ntu": 11,
  "source": "simulated"
}
```

Fields:

- `sample_id`: non-empty sample identifier.
- `temperature_c`: temperature in degrees Celsius.
- `ph`: pH value between 0 and 14.
- `conductivity_us_cm`: electrical conductivity in microsiemens per centimetre.
- `turbidity_ntu`: turbidity in NTU.
- `source`: `simulated` for software-generated values or `esp32` for device-originated values.

The example values above are test data only. Do not interpret them as a validated milk quality result. PASS/FAIL thresholds must be based on the project's research protocol and verified references, not invented defaults.
