import sys
from types import SimpleNamespace
from unittest.mock import Mock

import pytest
import runtime


@pytest.mark.parametrize("stale_environment", [False, True])
def test_render_starts_without_firebase_sdk_or_credentials(
    monkeypatch, tmp_path, stale_environment
):
    # Fail any attempted SDK import even if the developer has it installed.
    monkeypatch.setitem(sys.modules, "firebase_admin", None)
    monkeypatch.setenv("RENDER", "true")
    for name in ("FIREBASE_SERVICE_ACCOUNT_JSON", "GOOGLE_APPLICATION_CREDENTIALS"):
        if stale_environment:
            monkeypatch.setenv(name, "unused-invalid-value")
        else:
            monkeypatch.delenv(name, raising=False)
    monkeypatch.setattr(runtime, "BASE_DIR", tmp_path)
    model = Mock()
    loader = Mock(return_value=model)
    app = runtime.build_app(model_loader=loader)
    loader.assert_called_once_with(tmp_path)
    assert app.config["MODEL"] is model
    response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.json == {"status": "ok"}


def test_model_loading_failure_is_unhealthy_and_never_approves():
    from test_service import payload

    app = runtime.build_app(
        model_loader=Mock(side_effect=RuntimeError("bad checkpoint"))
    )
    client = app.test_client()
    assert client.get("/health").status_code == 503
    response = client.post("/predict", json=payload())
    assert response.status_code == 503
    assert response.json["error"] == "model_unavailable"
    assert "offensive" not in response.json


def test_model_path_is_independent_of_cwd(monkeypatch, tmp_path):
    backend = tmp_path / "backend"
    backend.mkdir()
    (backend / "model.pt").write_bytes(b"fake-model-for-path-test")
    model = Mock(
        names={0: "adult", 1: "racism", 2: "substance", 3: "violence", 4: "weapons"},
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
    assert runtime.load_model(backend) is model
    yolo.assert_called_once_with(str(backend / "model.pt"))
    assert model.call_count == 1  # warmup before readiness


def test_missing_model_does_not_trigger_download(tmp_path):
    with pytest.raises(RuntimeError, match="model_file_missing"):
        runtime.load_model(tmp_path)
