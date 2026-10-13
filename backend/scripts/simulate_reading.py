"""Send one clearly labelled simulated reading to the local API."""

import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

API_URL = "http://127.0.0.1:8000/api/v1/readings"

payload = {
    "sample_id": "DEMO-MILK-001",
    "temperature_c": 4.8,
    "ph": 6.7,
    "conductivity_us_cm": 850,
    "turbidity_ntu": 11,
    "source": "simulated",
}

request = Request(
    API_URL,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)

try:
    with urlopen(request, timeout=10) as response:
        print(f"HTTP {response.status}")
        print(response.read().decode("utf-8"))
except HTTPError as exc:
    print(f"API returned HTTP {exc.code}: {exc.read().decode('utf-8')}")
    raise SystemExit(1)
except URLError as exc:
    print(f"Could not reach {API_URL}: {exc.reason}")
    print("Start the API first with: python -m uvicorn app.main:app --reload")
    raise SystemExit(1)
