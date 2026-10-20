"""Encode the cattle / not-cattle text prompts with CLIP and save them for app.py.

Only needed if you change the prompts below. Requires the CLIP text model and
tokenizer, which the app itself does not need:

    pip install tokenizers onnxruntime
    curl -L -o text_model.onnx https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main/onnx/text_model.onnx
    curl -L -o tokenizer.json https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main/tokenizer.json
    python build_prompts.py text_model.onnx tokenizer.json
"""
import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort
from tokenizers import Tokenizer

# Close-ups matter: disease photos are often just skin, an udder, a hoof or a mouth.
CATTLE = [
    "a photo of a cow",
    "a photo of cattle",
    "a photo of a calf",
    "a photo of a bull",
    "a photo of a zebu",
    "a photo of a dairy cow",
    "a close-up photo of a cow's skin",
    "a close-up photo of skin lesions on cattle",
    "a photo of a cow with lumps on its skin",
    "a close-up photo of a cow's udder",
    "a close-up photo of a cow's teats",
    "a close-up photo of a cow's hoof",
    "a close-up photo of a cow's mouth",
]
NOT_CATTLE = [
    "a photo of a person",
    "a photo of a human face",
    "a close-up photo of human skin",
    "a photo of a dog",
    "a photo of a cat",
    "a photo of a goat",
    "a photo of a sheep",
    "a photo of a horse",
    "a photo of a pig",
    "a photo of a bird",
    "a photo of a wild animal",
    "a photo of food",
    "a photo of fruit",
    "a photo of a car",
    "a photo of a building",
    "a photo of a landscape",
    "a photo of a plant",
    "a photo of an object",
    "a drawing",
    "a painting",
    "a screenshot of text",
    "a microscope image",
    "an abstract pattern",
]


def main(text_model_path, tokenizer_path):
    tokenizer = Tokenizer.from_file(tokenizer_path)
    session = ort.InferenceSession(text_model_path, providers=["CPUExecutionProvider"])
    prompts = CATTLE + NOT_CATTLE
    encodings = tokenizer.encode_batch(prompts)
    length = max(len(e.ids) for e in encodings)
    # CLIP pools at the end-of-text token (highest id), so right-padding is safe.
    ids = np.array([e.ids + [e.ids[-1]] * (length - len(e.ids)) for e in encodings], dtype=np.int64)
    embeds = session.run(["text_embeds"], {"input_ids": ids})[0]
    embeds /= np.linalg.norm(embeds, axis=1, keepdims=True)

    out = Path(__file__).resolve().parent / "prompts.json"
    out.write_text(
        json.dumps(
            {
                "model": "openai/clip-vit-base-patch32",
                "prompts": [
                    {"text": p, "cattle": p in CATTLE, "embedding": [round(float(v), 6) for v in e]}
                    for p, e in zip(prompts, embeds)
                ],
            }
        ),
        encoding="utf-8",
    )
    print(f"Wrote {len(prompts)} prompts to {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
