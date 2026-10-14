"""Image-based cattle disease identification endpoint."""
import logging
from typing import TYPE_CHECKING

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import UnidentifiedImageError
from pydantic import BaseModel, Field

if TYPE_CHECKING:
    from app.disease.classifier import DiseaseClassifier

logger = logging.getLogger(__name__)

MAX_UPLOAD_BYTES = 10 * 1024 * 1024

router = APIRouter(prefix="/api/v1/disease", tags=["disease"])

_classifier: "DiseaseClassifier | None" = None
_load_error: str | None = None


def load_classifier() -> None:
    """Load the models once at startup. On failure the API still runs and the endpoint returns 503."""
    global _classifier, _load_error
    try:
        from app.disease.classifier import DiseaseClassifier

        _classifier = DiseaseClassifier()
        logger.info("Disease classifier loaded.")
    except Exception as exc:  # missing model files or ML dependencies
        _load_error = f"{type(exc).__name__}: {exc}"
        logger.warning("Disease classifier unavailable: %s", _load_error)


class DiseasePrediction(BaseModel):
    class_id: str = Field(examples=["LSD_High"])
    disease: str = Field(examples=["Lumpy Skin Disease"])
    severity: str | None = Field(description="Stage: High or Low. Null for Healthy.", examples=["High"])
    info: str
    confidence: float = Field(ge=0, le=1)


class DiseasePredictResponse(BaseModel):
    is_cattle: bool = Field(description="False when the photo does not appear to show cattle; no disease check is done then.")
    cattle_score: float = Field(ge=0, le=1)
    predictions: list[DiseasePrediction] = Field(description="Top 3 classes, most likely first. Empty when is_cattle is false.")
    gradcam_png: str | None = Field(description="Base64 PNG of the photo with a heatmap of the area that drove the top prediction.")


# A plain def runs in FastAPI's thread pool, so inference does not block the event loop.
@router.post("/predict", response_model=DiseasePredictResponse)
def predict(image: UploadFile = File(description="Photo of the animal or the affected area (JPG, PNG or WebP, up to 10 MB).")):
    if _classifier is None:
        raise HTTPException(503, f"Disease model is not available: {_load_error}")

    raw = image.file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Image is too large (10 MB max).")

    from app.disease.classifier import load_image

    try:
        img = load_image(raw)
    except (UnidentifiedImageError, OSError):
        raise HTTPException(400, "That file could not be read as an image.")

    return _classifier.predict(img)
