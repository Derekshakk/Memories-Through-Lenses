import json
import os
import subprocess
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest
import rekognition_provider
import runtime
import service
from test_service import payload

ROOT = Path(__file__).resolve().parents[1]
FAKE_KEY_ID = "test-access-key-id-not-real"
FAKE_SECRET = "fake-secret-access-key-for-tests-only"


def fake_aws(monkeypatch, region="us-west-2"):
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", FAKE_KEY_ID)
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", FAKE_SECRET)
    if region is not None:
        monkeypatch.setenv("AWS_REGION", region)


def captured_events():
    messages = []

    class Capture(service.logging.Handler):
        def emit(self, record):
            messages.append(json.loads(record.getMessage()))

    return messages, Capture()


@pytest.mark.parametrize("stale_environment", [False, True])
def test_render_starts_without_firebase_sdk_or_credentials(
    monkeypatch, stale_environment
):
    # Fail any attempted SDK import even if the developer has it installed.
    monkeypatch.setitem(sys.modules, "firebase_admin", None)
    monkeypatch.setenv("RENDER", "true")
    for name in ("FIREBASE_SERVICE_ACCOUNT_JSON", "GOOGLE_APPLICATION_CREDENTIALS"):
        if stale_environment:
            monkeypatch.setenv(name, "unused-invalid-value")
        else:
            monkeypatch.delenv(name, raising=False)
    provider = Mock()
    loader = Mock(return_value=provider)
    app = runtime.build_app(provider_loader=loader)
    loader.assert_called_once_with()
    assert app.config["PROVIDER"] is provider
    response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.json == {"status": "ok"}
    provider.moderate.assert_not_called()


def test_real_provider_loads_from_env_without_any_aws_request(monkeypatch):
    fake_aws(monkeypatch)
    app = runtime.build_app()
    assert app.test_client().get("/health").status_code == 200
    client = app.config["PROVIDER"]._client
    assert client.meta.region_name == "us-west-2"
    assert client.meta.config.connect_timeout == 2.0
    assert client.meta.config.read_timeout == 3.0
    assert client.meta.config.retries["total_max_attempts"] == 1
    assert client.meta.endpoint_url == "https://rekognition.us-west-2.amazonaws.com"


def test_aws_default_region_is_accepted(monkeypatch):
    fake_aws(monkeypatch, region=None)
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    client = rekognition_provider.create_client()
    assert client.meta.region_name == "us-east-1"


@pytest.mark.parametrize(
    "setup,code",
    [
        (lambda m: None, "aws_region_missing_or_invalid"),
        (lambda m: m.setenv("AWS_REGION", "us-west-2"), "aws_credentials_missing"),
        (
            lambda m: fake_aws(m, region="https://evil.example/"),
            "aws_region_missing_or_invalid",
        ),
        (lambda m: fake_aws(m, region="US-WEST-2"), "aws_region_missing_or_invalid"),
        (
            lambda m: (
                m.setenv("AWS_REGION", "us-west-2"),
                m.setenv("AWS_ACCESS_KEY_ID", FAKE_KEY_ID),
            ),
            "initialization_failed",  # partial credentials
        ),
    ],
)
def test_missing_aws_configuration_is_unhealthy_and_never_approves(
    monkeypatch, setup, code
):
    setup(monkeypatch)
    messages, handler = captured_events()
    service.logger.addHandler(handler)
    try:
        app = runtime.build_app()
    finally:
        service.logger.removeHandler(handler)
    assert {"stage": "provider_readiness", "event": "failure", "code": code} in messages
    assert FAKE_KEY_ID not in json.dumps(messages)
    client = app.test_client()
    assert client.get("/health").status_code == 503
    response = client.post("/predict", json=payload())
    assert response.status_code == 503
    assert response.json["error"] == "moderation_unavailable"
    assert "offensive" not in response.json


def test_provider_loader_exception_text_is_not_logged():
    messages, handler = captured_events()
    service.logger.addHandler(handler)
    try:
        app = runtime.build_app(
            provider_loader=Mock(side_effect=RuntimeError(FAKE_SECRET))
        )
    finally:
        service.logger.removeHandler(handler)
    assert FAKE_SECRET not in json.dumps(messages)
    assert app.test_client().get("/health").status_code == 503


def test_production_import_is_light_and_disables_ec2_metadata(tmp_path):
    environment = {
        "PATH": os.environ["PATH"],
        "AWS_ACCESS_KEY_ID": FAKE_KEY_ID,
        "AWS_SECRET_ACCESS_KEY": FAKE_SECRET,
        "AWS_REGION": "us-west-2",
        "AWS_CONFIG_FILE": str(tmp_path / "none"),
        "AWS_SHARED_CREDENTIALS_FILE": str(tmp_path / "none"),
        # Any accidental AWS request at import/startup would fail loudly here.
        "AWS_ENDPOINT_URL": "http://127.0.0.1:9",
    }
    script = (
        "import json, os, sys\n"
        "import app\n"
        "print(json.dumps({"
        "'metadata': os.environ.get('AWS_EC2_METADATA_DISABLED'),"
        "'heavy': sorted(m for m in ('torch', 'ultralytics', 'cv2', 'numpy',"
        " 'legacy_yolo') if m in sys.modules),"
        "'health': app.app.test_client().get('/health').status_code}))"
    )
    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
        timeout=60,
        check=True,
    )
    output = json.loads(result.stdout.strip().splitlines()[-1])
    assert output == {"metadata": "true", "heavy": [], "health": 200}
    assert FAKE_SECRET not in result.stdout + result.stderr
