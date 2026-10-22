"""Image-based cattle disease identification endpoints."""
import logging
from dataclasses import asdict
from datetime import datetime
from typing import TYPE_CHECKING, Annotated

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile
from PIL import UnidentifiedImageError
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import db_available, get_session, new_session
from app.disease.history import DiseaseScan, scan_from_result

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
    scan_id: int | None = Field(description="History id of the saved scan. Null when nothing was saved (not cattle, or no database).")


class ScanSummary(BaseModel):
    id: int
    created_at: datetime
    top_prediction: DiseasePrediction
    photo_url: str = Field(description="Path of the stored photo (JPEG), relative to the API base URL.")


class ScanHistoryResponse(BaseModel):
    total: int
    items: list[ScanSummary] = Field(description="Newest first.")


class ScanDetail(BaseModel):
    id: int
    created_at: datetime
    cattle_score: float = Field(ge=0, le=1)
    predictions: list[DiseasePrediction] = Field(description="Top 3 classes, most likely first.")
    photo_url: str
    gradcam_url: str | None = Field(description="Path of the stored Grad-CAM overlay (JPEG).")


def _photo_url(scan_id: int) -> str:
    return f"{router.prefix}/history/{scan_id}/photo"


# A plain def runs in FastAPI's thread pool, so inference does not block the event loop.
@router.post("/predict", response_model=DiseasePredictResponse)
def predict(image: UploadFile = File(description="Photo of the animal or the affected area (JPG, PNG or WebP, up to 10 MB).")):
    """Check a photo for cattle diseases.

    First checks that the photo shows cattle, then returns the top 3 disease classes
    with a Grad-CAM heatmap. Cattle scans are saved to the history when a database is set up.
    Returns 400 for an unreadable image, 413 for a file over 10 MB and 503 when the model is not loaded.
    """
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

    result = _classifier.predict(img)

    # Keep cattle scans in the history. A failed save must not lose the result.
    scan_id = None
    if result.is_cattle and db_available():
        try:
            with new_session() as session:
                scan = scan_from_result(img, result)
                session.add(scan)
                session.commit()
                scan_id = scan.id
        except Exception:
            logger.exception("Could not save the scan to history.")

    return DiseasePredictResponse(**asdict(result), scan_id=scan_id)


@router.get("/history", response_model=ScanHistoryResponse)
def list_history(
    session: Annotated[Session, Depends(get_session)],
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    """A page of saved scans, newest first, with each scan's top prediction."""
    total = session.scalar(select(func.count()).select_from(DiseaseScan))
    scans = session.scalars(select(DiseaseScan).order_by(DiseaseScan.id.desc()).limit(limit).offset(offset))
    return ScanHistoryResponse(
        total=total or 0,
        items=[
            ScanSummary(
                id=s.id,
                created_at=s.created_at,
                top_prediction=DiseasePrediction.model_validate(s.predictions[0]),
                photo_url=_photo_url(s.id),
            )
            for s in scans
        ],
    )


def _get_scan(session: Session, scan_id: int) -> DiseaseScan:
    """Load a scan, or raise 404 if it does not exist."""
    scan = session.get(DiseaseScan, scan_id)
    if scan is None:
        raise HTTPException(404, "Scan not found.")
    return scan


@router.get("/history/{scan_id}", response_model=ScanDetail)
def get_scan(scan_id: int, session: Annotated[Session, Depends(get_session)]):
    """Full details of one saved scan: all 3 predictions and links to its images."""
    scan = _get_scan(session, scan_id)
    # Check in SQL so the heatmap bytes are not loaded just to see if they exist.
    has_gradcam = session.scalar(select(DiseaseScan.gradcam_jpeg.is_not(None)).where(DiseaseScan.id == scan_id))
    return ScanDetail(
        id=scan.id,
        created_at=scan.created_at,
        cattle_score=scan.cattle_score,
        predictions=[DiseasePrediction.model_validate(p) for p in scan.predictions],
        photo_url=_photo_url(scan.id),
        gradcam_url=f"{router.prefix}/history/{scan.id}/gradcam" if has_gradcam else None,
    )


# Stored images never change, so clients may cache them.
_IMAGE_HEADERS = {"Cache-Control": "private, max-age=86400"}


@router.get("/history/{scan_id}/photo", response_class=Response, responses={200: {"content": {"image/jpeg": {}}}})
def get_scan_photo(scan_id: int, session: Annotated[Session, Depends(get_session)]):
    """The photo that was scanned, as a JPEG."""
    return Response(_get_scan(session, scan_id).photo_jpeg, media_type="image/jpeg", headers=_IMAGE_HEADERS)


@router.get("/history/{scan_id}/gradcam", response_class=Response, responses={200: {"content": {"image/jpeg": {}}}})
def get_scan_gradcam(scan_id: int, session: Annotated[Session, Depends(get_session)]):
    """The Grad-CAM heatmap overlay of a scan, as a JPEG. 404 if the scan has none."""
    gradcam = _get_scan(session, scan_id).gradcam_jpeg
    if gradcam is None:
        raise HTTPException(404, "This scan has no heatmap.")
    return Response(gradcam, media_type="image/jpeg", headers=_IMAGE_HEADERS)


@router.delete("/history/{scan_id}", status_code=204)
def delete_scan(scan_id: int, session: Annotated[Session, Depends(get_session)]):
    """Delete a scan and its stored images from the history."""
    session.delete(_get_scan(session, scan_id))
    session.commit()
