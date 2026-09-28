"""DEPRECATED YOLO checkpoint helpers remain testable without Torch installed."""

import sys
from types import SimpleNamespace
from unittest.mock import Mock

import pytest
from legacy_yolo import yolo_checkpoint
from PIL import Image
from service import Failure


def test_model_path_is_independent_of_cwd(monkeypatch, tmp_path):
    backend = tmp_path / "backend"
    backend.mkdir()
    (backend / "model.pt").write_bytes(b"fake-model-for-path-test")
    model = Mock(
        names=dict(
            enumerate(["adult", "racism", "substance", "violence", "weapons", "none"])
        ),
        task="detect",
    )
    model.return_value = [SimpleNamespace(boxes=[])]
    yolo = Mock(return_value=model)
    monkeypatch.setitem(sys.modules, "torch", SimpleNamespace(set_num_threads=Mock()))
    monkeypatch.setitem(sys.modules, "ultralytics", SimpleNamespace(YOLO=yolo))
    monkeypatch.setitem(
        sys.modules, "ultralytics.utils", SimpleNamespace(LOGGER=Mock())
    )
    monkeypatch.chdir(tmp_path)
    assert yolo_checkpoint.load_model(backend) is model
    yolo.assert_called_once_with(str(backend / "model.pt"))
    assert model.call_args.kwargs["imgsz"] == 640


def test_missing_model_does_not_trigger_download(tmp_path):
    with pytest.raises(RuntimeError, match="model_file_missing"):
        yolo_checkpoint.load_model(tmp_path)


def test_historical_checkpoint_is_still_in_repository():
    assert (yolo_checkpoint.MODEL_DIR / "model.pt").is_file()


@pytest.mark.parametrize("confidence,offensive", [(0.7, False), (0.71, True)])
def test_legacy_provider_keeps_historical_rule(confidence, offensive):
    model = Mock(
        names={4: "weapons"},
        return_value=[SimpleNamespace(boxes=[SimpleNamespace(cls=4, conf=confidence)])],
    )
    with Image.new("RGB", (100, 80)) as image:
        verdict = yolo_checkpoint.LegacyYoloProvider(model).moderate(image, 0)
    assert verdict.offensive is offensive


def test_legacy_unknown_class_fails_explicitly():
    model = Mock(
        names={0: "unreviewed-class"},
        return_value=[SimpleNamespace(boxes=[SimpleNamespace(cls=0, conf=0.99)])],
    )
    with Image.new("RGB", (100, 80)) as image, pytest.raises(Failure):
        yolo_checkpoint.LegacyYoloProvider(model).moderate(image, 0)
