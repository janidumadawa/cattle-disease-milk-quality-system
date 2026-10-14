
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.disease.router import load_classifier
from app.disease.router import router as disease_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    load_classifier()
    yield


app = FastAPI(
    title="MedFarm API",
    description="Shared API foundation for the MedFarm research project.",
    version="0.1.0",
    lifespan=lifespan,
)

# The Flutter web dev server runs on a random localhost port.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(disease_router)


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
