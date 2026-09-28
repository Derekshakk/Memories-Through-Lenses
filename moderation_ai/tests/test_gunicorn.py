"""Real process-level checks with Gunicorn on loopback. Never contacts AWS."""

import importlib.util
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from contextlib import contextmanager
from pathlib import Path

import pytest
from test_service import payload

ROOT = Path(__file__).resolve().parents[1]
FAKE_KEY_ID = "test-access-key-id-not-real"
FAKE_SECRET = "fake-secret-access-key-for-tests-only"
requires_gunicorn = pytest.mark.skipif(
    importlib.util.find_spec("gunicorn") is None,
    reason="Gunicorn runtime not installed",
)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


@contextmanager
def gunicorn(tmp_path, args, environment):
    port = free_port()
    with (tmp_path / "worker.log").open("w+") as log:
        process = subprocess.Popen(
            [sys.executable, "-m", "gunicorn", "--bind", f"127.0.0.1:{port}", *args],
            cwd=ROOT,
            env=environment,
            stdout=log,
            stderr=log,
        )
        try:
            yield f"http://127.0.0.1:{port}", log
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)


def wait_for_health(url, expected_status, seconds=15):
    deadline = time.monotonic() + seconds
    while True:
        try:
            with urllib.request.urlopen(url + "/health", timeout=0.5) as response:
                status = response.status
        except urllib.error.HTTPError as error:
            status = error.code
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            status = None
        if status is not None:
            assert status == expected_status
            return
        if time.monotonic() > deadline:
            pytest.fail("Gunicorn did not start")
        time.sleep(0.05)


def post(url, body):
    request = urllib.request.Request(
        url + "/predict?token=must-not-appear-in-logs",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=6) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def clean_environment(tmp_path, **extra):
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("AWS_") and "PROXY" not in key.upper()
    }
    environment.update(
        GUNICORN_CMD_ARGS="",
        AWS_CONFIG_FILE=str(tmp_path / "none"),
        AWS_SHARED_CREDENTIALS_FILE=str(tmp_path / "none"),
        # Any accidental AWS request would go to a closed loopback port.
        AWS_ENDPOINT_URL="http://127.0.0.1:9",
        **extra,
    )
    return environment


@requires_gunicorn
@pytest.mark.parametrize("startup_delay", [0, 3])
def test_gunicorn_kills_stuck_worker_without_late_approval(tmp_path, startup_delay):
    (tmp_path / "stuck_wsgi.py").write_text(
        f"""
from io import BytesIO
import time
from PIL import Image
from service import create_app
time.sleep({startup_delay})
class StuckProvider:
    def moderate(self, *_args):
        time.sleep(30)
        raise RuntimeError('must not reach this line')
def image(*_args):
    buffer = BytesIO()
    Image.new('RGB', (120, 90)).save(buffer, format='PNG')
    return buffer.getvalue()
app = create_app(provider=StuckProvider(), fetcher=image)
"""
    )
    environment = clean_environment(
        tmp_path, PYTHONPATH=os.pathsep.join([str(ROOT), str(tmp_path)])
    )
    args = ["--workers", "1", "--threads", "1", "--timeout", "2", "stuck_wsgi:app"]
    with gunicorn(tmp_path, args, environment) as (url, log):
        wait_for_health(url, 200, seconds=8)
        started = time.monotonic()
        request = urllib.request.Request(
            url + "/predict?token=must-not-appear-in-logs",
            data=json.dumps(payload()).encode(),
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=6) as response:
                assert response.status >= 500
        except urllib.error.HTTPError as error:
            assert error.code >= 500
        except (ConnectionError, OSError):
            pass  # Worker termination closes the socket; never an approval.
        assert time.monotonic() - started < 5
        log.flush()
        log.seek(0)
        output = log.read()
        assert '"code": "worker_timeout"' in output
        assert "must-not-appear-in-logs" not in output


@requires_gunicorn
@pytest.mark.parametrize("configured", [True, False])
def test_production_app_starts_under_gunicorn_config_without_aws_calls(
    tmp_path, configured
):
    extra = {"AWS_EC2_METADATA_DISABLED": "true"}
    if configured:
        extra.update(
            AWS_ACCESS_KEY_ID=FAKE_KEY_ID,
            AWS_SECRET_ACCESS_KEY=FAKE_SECRET,
            AWS_REGION="us-west-2",
        )
    environment = clean_environment(tmp_path, **extra)
    args = ["--config", "gunicorn.conf.py", "app:app"]
    with gunicorn(tmp_path, args, environment) as (url, log):
        wait_for_health(url, 200 if configured else 503)
        # Invalid input is rejected before any fetch or AWS request.
        body = payload()
        body["url"] = "https://169.254.169.254/latest/meta-data"
        status, response = post(url, body)
        assert status == 400
        assert set(response) == {"error", "request_id"}
        if not configured:
            status, response = post(url, payload())
            assert status == 503
            assert response["error"] == "moderation_unavailable"
        log.flush()
        log.seek(0)
        output = log.read()
    assert (
        '"stage": "provider_readiness", "event": "%s"'
        % ("success" if configured else "failure")
        in output
    )
    for secret in (FAKE_SECRET, FAKE_KEY_ID, "must-not-appear-in-logs", "169.254"):
        assert secret not in output
