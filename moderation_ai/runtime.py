"""Production startup; tests inject a model without importing Torch or YOLO."""

import logging
from pathlib import Path

from firebase_runtime import initialize_firebase
from service import OFFENSIVE_CLASSES, create_app, event, predictions_from_results

BASE_DIR = Path(__file__).resolve().parent


def load_model(base_dir=BASE_DIR):
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
    if not OFFENSIVE_CLASSES.issubset(names) or model.task != "detect":
        raise RuntimeError("unexpected_model")
    # First-use model setup must finish before /health becomes ready.
    with Image.new("RGB", (64, 64)) as sample:
        predictions_from_results(model([sample], verbose=False), model.names)
    return model


def build_app(*, firebase_loader=initialize_firebase, model_loader=load_model):
    stage = "firebase_initialization"
    try:
        event(stage, "start")
        firebase_loader(BASE_DIR)
        event(stage, "success")
        stage = "model_readiness"
        event(stage, "start")
        model = model_loader(BASE_DIR)
        event(stage, "success")
        return create_app(model=model)
    except Exception:
        event(stage, "failure", code="initialization_failed")
        # Process stays inspectable; health is 503 and prediction cannot approve.
        return create_app(startup_ready=False)
