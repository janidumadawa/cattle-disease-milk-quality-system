"""Draw a Grad-CAM heatmap over the original photo."""
import base64
import io

import numpy as np
from PIL import Image

OVERLAY_MAX_SIDE = 640  # longest side of the returned image
OVERLAY_ALPHA = 0.4  # heatmap weight in the blend, as in gradcam_function.py


def jet(values: np.ndarray) -> np.ndarray:
    """Map values in [0, 1] to RGB uint8 with the JET colormap (blue to red)."""
    v = values[..., None]
    rgb = np.clip(1.5 - np.abs(4 * v - np.array([3.0, 2.0, 1.0])), 0, 1)
    return (rgb * 255).astype(np.uint8)


def overlay_png(img: Image.Image, cam: np.ndarray) -> str:
    """Blend the heatmap (values in [0, 1]) over the photo and return it as base64 PNG."""
    display = img.copy()
    display.thumbnail((OVERLAY_MAX_SIDE, OVERLAY_MAX_SIDE))
    heat = Image.fromarray((255 * cam).astype(np.uint8)).resize(display.size, Image.Resampling.BILINEAR)
    colored = Image.fromarray(jet(np.asarray(heat, dtype="float32") / 255))
    overlay = Image.blend(display, colored, OVERLAY_ALPHA)
    buf = io.BytesIO()
    overlay.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")
