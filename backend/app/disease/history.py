"""Scan history: each cattle photo and its result, kept in the database.

The photo and the Grad-CAM overlay are stored as JPEG bytes in the same row, so
no separate file bucket is needed.
"""
import base64
import io
from dataclasses import asdict
from datetime import datetime
from typing import TYPE_CHECKING

from PIL import Image
from sqlalchemy import DateTime, Float, Integer, LargeBinary, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

if TYPE_CHECKING:
    from app.disease.classifier import Result

PHOTO_MAX_SIDE = 1024  # enough to view on a phone; keeps rows small
JPEG_QUALITY = 85


class DiseaseScan(Base):
    __tablename__ = "disease_scans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
    cattle_score: Mapped[float] = mapped_column(Float)
    predictions: Mapped[list[dict]] = mapped_column(JSONB)  # top 3, most likely first
    # Deferred: the history list loads rows without their images.
    photo_jpeg: Mapped[bytes] = mapped_column(LargeBinary, deferred=True)
    gradcam_jpeg: Mapped[bytes | None] = mapped_column(LargeBinary, deferred=True)


def _to_jpeg(img: Image.Image) -> bytes:
    img = img.copy()
    img.thumbnail((PHOTO_MAX_SIDE, PHOTO_MAX_SIDE))
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="JPEG", quality=JPEG_QUALITY)
    return buf.getvalue()


def scan_from_result(img: Image.Image, result: "Result") -> DiseaseScan:
    """Build a row for a cattle photo. Only call when result.is_cattle is True."""
    gradcam = None
    if result.gradcam_png is not None:
        gradcam = _to_jpeg(Image.open(io.BytesIO(base64.b64decode(result.gradcam_png))))
    return DiseaseScan(
        cattle_score=result.cattle_score,
        predictions=[asdict(p) for p in result.predictions],
        photo_jpeg=_to_jpeg(img),
        gradcam_jpeg=gradcam,
    )
