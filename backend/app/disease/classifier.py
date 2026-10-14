"""Cattle disease classifier.

Model files live in backend/models/disease.
"""
import io
import json
import os
import threading
from dataclasses import dataclass
from pathlib import Path

# Keras 3 on JAX: TensorFlow has no wheels for newer Python versions, and the
# Grad-CAM below takes gradients with jax.grad, so this needs the JAX backend.
os.environ["KERAS_BACKEND"] = "jax"

import jax
import jax.numpy as jnp
import keras
import numpy as np
from PIL import Image, ImageOps

from app.disease.gradcam import overlay_png

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
    gradcam_png: str  # base64 PNG of the heatmap over the photo


class DiseaseClassifier:
    def __init__(self):
        model = keras.saving.load_model(MODEL_PATH, compile=False)
        if not isinstance(model, keras.Model):
            raise RuntimeError(f"{MODEL_PATH.name} did not load as a Keras model.")
        self._model = model
        self._lock = threading.Lock()
        self.classes = json.loads(CLASSES_PATH.read_text(encoding="utf-8"))["classes"]
        model_class_ids = json.loads(MODEL_LABELS_PATH.read_text(encoding="utf-8"))

        num_outputs = model.output_shape[-1]
        if len(model_class_ids) != num_outputs:
            raise RuntimeError(f"{MODEL_LABELS_PATH.name} has {len(model_class_ids)} classes but the model outputs {num_outputs}.")
        if [c["id"] for c in self.classes] != model_class_ids:
            raise RuntimeError(f"{CLASSES_PATH.name} class ids must match {MODEL_LABELS_PATH} in the same order.")

        # Grad-CAM setup, following gradcam_function.py: target the last Conv2D in
        # the nested backbone, then replay the remaining layers to get the scores.
        backbone = next(layer for layer in model.layers if isinstance(layer, keras.Model))
        target_index = max(i for i, layer in enumerate(backbone.layers) if isinstance(layer, keras.layers.Conv2D))
        feature_model = keras.Model(backbone.inputs, backbone.layers[target_index].output)
        head_layers = backbone.layers[target_index + 1:] + model.layers[model.layers.index(backbone) + 1:]

        def head(features):
            for layer in head_layers:
                features = layer(features, training=False)
            return features

        @jax.jit
        def predict_with_cam(batch):
            """Return (class probabilities, Grad-CAM map in [0, 1]) for a single-image batch."""
            features = feature_model(batch, training=False)
            probs = head(features)
            class_idx = jnp.argmax(probs[0])
            grads = jax.grad(lambda f: head(f)[0, class_idx])(features)
            weights = grads.mean(axis=(1, 2))
            cam = jax.nn.relu((features[0] * weights[0]).sum(axis=-1))
            return probs[0], cam / (cam.max() + 1e-8)

        self._predict_with_cam = predict_with_cam

        # The first call compiles the graph; do it now so the first request is fast.
        # Also check the replayed head gives the same scores as the full model.
        warmup = np.zeros((1, *IMG_SIZE, 3), dtype="float32")
        if not np.allclose(predict_with_cam(warmup)[0], np.asarray(model(warmup, training=False))[0], atol=1e-4):
            raise RuntimeError("Grad-CAM layer replay does not match the model's predictions.")

    def predict(self, img: Image.Image) -> Result:
        with self._lock:
            probs, cam = self._predict_with_cam(_preprocess(img))
            probs, cam = np.asarray(probs), np.asarray(cam)

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
            gradcam_png=overlay_png(img, cam),
        )


def load_image(raw: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(raw))
    return ImageOps.exif_transpose(img).convert("RGB")


def _preprocess(img: Image.Image) -> np.ndarray:
    # The model's own Rescaling layer maps 0-255 to [-1, 1], so pass raw pixels.
    resized = img.resize(IMG_SIZE, Image.Resampling.BILINEAR)
    return np.asarray(resized, dtype="float32")[None, ...]
