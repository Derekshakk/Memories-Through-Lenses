import json
import sys
from types import SimpleNamespace
from unittest.mock import Mock

import firebase_runtime
import pytest
import runtime


@pytest.fixture
def sdk(monkeypatch):
    certificate = Mock(return_value="credential-object")
    initialize = Mock(return_value="firebase-app")
    module = SimpleNamespace(
        credentials=SimpleNamespace(Certificate=certificate), initialize_app=initialize
    )
    monkeypatch.setitem(sys.modules, "firebase_admin", module)
    for name in [
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        "GOOGLE_APPLICATION_CREDENTIALS",
        "RENDER",
    ]:
        monkeypatch.delenv(name, raising=False)
    return certificate, initialize


def credential():
    return {
        "type": "service_account",
        "project_id": "memories-through-lenses",
        "private_key": "fake-private-value",
    }


def test_json_secret_initializes_without_file(sdk, monkeypatch, tmp_path):
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", json.dumps(credential()))
    assert firebase_runtime.initialize_firebase(tmp_path) == "firebase-app"
    sdk[0].assert_called_once_with(credential())
    assert sdk[1].call_args.kwargs["name"] == "memolens-moderation"


def test_secret_file_path_and_local_fallback(sdk, monkeypatch, tmp_path):
    (tmp_path / "firebase-key.json").write_text(json.dumps(credential()))
    monkeypatch.chdir(tmp_path.parent)
    assert firebase_runtime.initialize_firebase(tmp_path) == "firebase-app"
    monkeypatch.setenv("RENDER", "true")
    monkeypatch.setenv(
        "GOOGLE_APPLICATION_CREDENTIALS", str(tmp_path / "firebase-key.json")
    )
    assert firebase_runtime.initialize_firebase(tmp_path) == "firebase-app"


def test_render_never_implicitly_reads_local_key(sdk, monkeypatch, tmp_path):
    monkeypatch.setenv("RENDER", "true")
    (tmp_path / "firebase-key.json").write_text(json.dumps(credential()))
    with pytest.raises(RuntimeError, match="^firebase_initialization_failed$"):
        firebase_runtime.initialize_firebase(tmp_path)
    sdk[0].assert_not_called()


@pytest.mark.parametrize(
    "content", ["private-key-bad-json", "[]", '{"project_id":"other"}']
)
def test_invalid_credentials_have_safe_error(sdk, monkeypatch, tmp_path, content):
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", content)
    with pytest.raises(RuntimeError, match="^firebase_initialization_failed$"):
        firebase_runtime.initialize_firebase(tmp_path)


def test_ambiguous_credentials_fail(sdk, monkeypatch, tmp_path):
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", json.dumps(credential()))
    monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", "elsewhere.json")
    with pytest.raises(RuntimeError):
        firebase_runtime.initialize_firebase(tmp_path)


def test_startup_failure_is_unhealthy_and_never_approves():
    loader = Mock(side_effect=ValueError("private-secret"))
    model_loader = Mock()
    app = runtime.build_app(firebase_loader=loader, model_loader=model_loader)
    response = app.test_client().get("/health")
    assert response.status_code == 503
    assert response.json == {"status": "unavailable"}
    model_loader.assert_not_called()


def test_model_loading_failure_is_unhealthy():
    app = runtime.build_app(
        firebase_loader=Mock(),
        model_loader=Mock(side_effect=RuntimeError("bad checkpoint")),
    )
    assert app.test_client().get("/health").status_code == 503


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
