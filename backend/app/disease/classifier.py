"""Cattle disease classifier.

Model files live in backend/models/disease.
"""
import io
import json
import os
import threading
from dataclasses import dataclass
from pathlib import Path

# Keras 3 on JAX: TensorFlow has no wheels for newer Python versions.
os.environ["KERAS_BACKEND"] = "jax"

import keras
import numpy as np
from PIL import Image, ImageOps

MODEL_DIR = Path(__file__).resolve().parents[2] / "models" / "disease"
MODEL_PATH = MODEL_DIR / "cattle_disease_classifier.keras"
MODEL_LABELS_PATH = MODEL_DIR / "labels.json"  # class order shipped with the model
CLASSES_PATH = Path(__file__).resolve().parent / "classes.json"  # display names and info

IMG_SIZE = (224, 224)
TOP_K = 3


@dataclass
class Prediction:
    class_id: str
    disease: str
    severity: str | None
    info: str
    confidence: float


@dataclass
class Result:
    predictions: list[Prediction]


class DiseaseClassifier:
    def __init__(self):
        self._model = keras.saving.load_model(MODEL_PATH, compile=False)
        self._lock = threading.Lock()
        self.classes = json.loads(CLASSES_PATH.read_text(encoding="utf-8"))["classes"]
        model_class_ids = json.loads(MODEL_LABELS_PATH.read_text(encoding="utf-8"))

        num_outputs = self._model.output_shape[-1]
        if len(model_class_ids) != num_outputs:
            raise RuntimeError(f"{MODEL_LABELS_PATH.name} has {len(model_class_ids)} classes but the model outputs {num_outputs}.")
        if [c["id"] for c in self.classes] != model_class_ids:
            raise RuntimeError(f"{CLASSES_PATH.name} class ids must match {MODEL_LABELS_PATH} in the same order.")

    def predict(self, img: Image.Image) -> Result:
        with self._lock:
            probs = self._model.predict(_preprocess(img), verbose=0)[0]

        order = np.argsort(probs)[::-1][:TOP_K]
        return Result(
            predictions=[
                Prediction(
                    class_id=self.classes[i]["id"],
                    disease=self.classes[i]["disease"],
                    severity=self.classes[i]["severity"],
                    info=self.classes[i]["info"],
                    confidence=float(probs[i]),
                )
                for i in order
            ],
        )


def load_image(raw: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(raw))
    return ImageOps.exif_transpose(img).convert("RGB")


def _preprocess(img: Image.Image) -> np.ndarray:
    # The model's own Rescaling layer maps 0-255 to [-1, 1], so pass raw pixels.
    resized = img.resize(IMG_SIZE, Image.Resampling.BILINEAR)
    return np.asarray(resized, dtype="float32")[None, ...]
