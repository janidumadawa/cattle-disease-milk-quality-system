# Python Backend

FastAPI service for the cattle disease and raw milk quality system.

## Requirements

- Python 3.11 or newer
- Internet access for installing packages

## Run locally (Windows PowerShell)

From the repository root:

```powershell
cd backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
python -m uvicorn app.main:app --reload
```

Open:

- API health: http://127.0.0.1:8000/health
- Interactive API docs: http://127.0.0.1:8000/docs

## Send one simulated reading

Keep the server running in the first terminal. Open a second PowerShell terminal:

```powershell
cd path\to\cattle-disease-milk-quality-system\backend
.\.venv\Scripts\Activate.ps1
python scripts/simulate_reading.py
```

The values sent by this script are **simulated examples**, not results from a real milk sample. The current endpoint validates and returns readings but does not store them. Database persistence will be implemented after the Neon database is configured.

## Environment variables

Copy `.env.example` to `.env` when database integration is introduced. Never commit the real `.env` file or credentials.
