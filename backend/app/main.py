
from fastapi import FastAPI

app = FastAPI(
    title="MedFarm API",
    description="Shared API foundation for the MedFarm research project.",
    version="0.1.0",
)


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
