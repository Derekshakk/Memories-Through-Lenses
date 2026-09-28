"""DEPRECATED: the bundled YOLO checkpoint (../model.pt) is not production-safe.

It produced high-confidence false positives on benign school photos (see
../docs/model-quality-investigation.md). Kept only for historical comparison
and investigation. Production uses rekognition_provider.py. Requires
legacy_yolo/requirements.txt (Torch/Ultralytics), which production does not
install.
"""

import logging
import math
from pathlib import Path

from service import Failure, Verdict

MODEL_DIR = Path(__file__).resolve().parents[1]
OFFENSIVE_CLASSES = {"adult", "racism", "substance", "violence", "weapons"}
SUPPORTED_CLASSES = OFFENSIVE_CLASSES | {"none"}
MODEL_IMAGE_SIZE = 640
OFFENSIVE_THRESHOLD = 0.7


def predictions_from_results(results, names) -> list[dict]:
    try:
        if len(results) != 1 or results[0].boxes is None:
            raise ValueError
        predictions = []
        for box in results[0].boxes:
            class_number, confidence = float(box.cls), float(box.conf)
            if (
                not math.isfinite(class_number)
                or class_number < 0
                or not class_number.is_integer()
                or not math.isfinite(confidence)
                or not 0 <= confidence <= 1
            ):
                raise ValueError
            label = names[int(class_number)]
            if not isinstance(label, str) or label not in SUPPORTED_CLASSES:
                raise ValueError
            predictions.append({"class": label, "confidence": confidence})
        return predictions
    except (TypeError, ValueError, AttributeError, KeyError, IndexError, OverflowError):
        raise Failure("invalid_inference_result", 503) from None


def load_model(base_dir=MODEL_DIR):
    # Fail explicitly if the bundled checkpoint is absent; never download a model.
    model_path = base_dir / "model.pt"
    if not model_path.is_file():
        raise RuntimeError("model_file_missing")
    import torch
    from PIL import Image
    from ultralytics import YOLO
    from ultralytics.utils import LOGGER

    LOGGER.setLevel(logging.ERROR)
    torch.set_num_threads(1)
    model = YOLO(str(model_path))
    names = (
        set(model.names.values()) if isinstance(model.names, dict) else set(model.names)
    )
    if names != SUPPORTED_CLASSES or model.task != "detect":
        raise RuntimeError("unexpected_model")
    with Image.new("RGB", (MODEL_IMAGE_SIZE, MODEL_IMAGE_SIZE)) as sample:
        predictions_from_results(
            model([sample], verbose=False, imgsz=MODEL_IMAGE_SIZE), model.names
        )
    return model


class LegacyYoloProvider:
    """Historical verdict rule: any offensive class above 0.7 confidence."""

    def __init__(self, model):
        self.model = model

    def moderate(self, image, deadline) -> Verdict:
        predictions = predictions_from_results(
            self.model([image], verbose=False, imgsz=MODEL_IMAGE_SIZE),
            self.model.names,
        )
        offensive = any(
            p["class"] in OFFENSIVE_CLASSES and p["confidence"] > OFFENSIVE_THRESHOLD
            for p in predictions
        )
        return Verdict(offensive, predictions, {"provider": "legacy_yolo"})
