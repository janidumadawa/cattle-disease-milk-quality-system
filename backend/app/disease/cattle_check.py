"""Check whether a photo shows cattle before running the disease model.

The disease model always picks one of its classes, even for a photo of a
person, so CLIP first scores the photo against cattle / not-cattle text
prompts. The prompts are pre-encoded by models/disease/cattle_check/build_prompts.py.
"""
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps

GATE_DIR = Path(__file__).resolve().parents[2] / "models" / "disease" / "cattle_check"
GATE_THRESHOLD = 0.5  # minimum share of CLIP probability on the cattle prompts

CLIP_MEAN = np.array([0.48145466, 0.4578275, 0.40821073], dtype=np.float32)
CLIP_STD = np.array([0.26862954, 0.26130258, 0.27577711], dtype=np.float32)
CLIP_SIZE = 224


class CattleChecker:
    def __init__(self):
        self._session = ort.InferenceSession(str(GATE_DIR / "clip_vision_quantized.onnx"), providers=["CPUExecutionProvider"])
        prompts = json.loads((GATE_DIR / "prompts.json").read_text(encoding="utf-8"))["prompts"]
        self._text = np.array([p["embedding"] for p in prompts], dtype=np.float32)
        self._is_cattle = np.array([p["cattle"] for p in prompts])

    def score(self, img: Image.Image) -> float:
        """Probability (0-1) that the photo shows cattle or a close-up of part of one."""
        # Two views, averaged: CLIP's usual center crop, and the whole photo padded
        # to a square so an animal near the edge is not cropped away.
        w, h = img.size
        scale = CLIP_SIZE / min(w, h)
        resized = img.resize(
            (max(CLIP_SIZE, round(w * scale)), max(CLIP_SIZE, round(h * scale))), Image.Resampling.BICUBIC
        )
        left, top = (resized.width - CLIP_SIZE) // 2, (resized.height - CLIP_SIZE) // 2
        crop = resized.crop((left, top, left + CLIP_SIZE, top + CLIP_SIZE))
        padded = ImageOps.pad(
            img, (CLIP_SIZE, CLIP_SIZE), Image.Resampling.BICUBIC, color=tuple(int(m * 255) for m in CLIP_MEAN)
        )

        pixels = np.stack([(np.asarray(v, dtype=np.float32) / 255 - CLIP_MEAN) / CLIP_STD for v in (crop, padded)])
        embeds = np.asarray(self._session.run(["image_embeds"], {"pixel_values": pixels.transpose(0, 3, 1, 2)})[0])
        embed = (embeds / np.linalg.norm(embeds, axis=1, keepdims=True)).mean(axis=0)
        logits = 100 * (self._text @ (embed / np.linalg.norm(embed)))  # CLIP's logit scale
        probs = np.exp(logits - logits.max())
        return float(probs[self._is_cattle].sum() / probs.sum())

    def is_cattle(self, img: Image.Image) -> tuple[bool, float]:
        score = self.score(img)
        return score >= GATE_THRESHOLD, score
