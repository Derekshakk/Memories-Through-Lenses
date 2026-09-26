"""Real process-level check: stuck native-style work cannot return late approval."""

import importlib.util
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest
from test_service import payload


@pytest.mark.skipif(
    importlib.util.find_spec("gunicorn") is None,
    reason="Gunicorn runtime not installed",
)
@pytest.mark.parametrize("startup_delay", [0, 3])
def test_gunicorn_kills_stuck_worker_without_late_approval(tmp_path, startup_delay):
    root = Path(__file__).resolve().parents[1]
    (tmp_path / "stuck_wsgi.py").write_text(
        """
from io import BytesIO
import time
from PIL import Image
from service import create_app
class StuckModel:
    names = {}
    def __call__(self, *_args, **_kwargs):
        time.sleep(30)
        raise RuntimeError('must not reach this line')
def image(*_args):
    buffer = BytesIO()
    Image.new('RGB', (64, 64)).save(buffer, format='PNG')
    return buffer.getvalue()
app = create_app(model=StuckModel(), fetcher=image)
""".replace(
            "from service import create_app",
            f"from service import create_app\ntime.sleep({startup_delay})",
        )
    )
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    environment = dict(
        os.environ,
        PYTHONPATH=os.pathsep.join([str(root), str(tmp_path)]),
        GUNICORN_CMD_ARGS="",
    )
    with (tmp_path / "worker.log").open("w+") as log:
        process = subprocess.Popen(
            [
                sys.executable,
                "-m",
                "gunicorn",
                "--bind",
                f"127.0.0.1:{port}",
                "--workers",
                "1",
                "--threads",
                "1",
                "--timeout",
                "2",
                "stuck_wsgi:app",
            ],
            cwd=root,
            env=environment,
            stdout=log,
            stderr=log,
        )
        try:
            url = f"http://127.0.0.1:{port}"
            deadline = time.monotonic() + 8
            while True:
                try:
                    with urllib.request.urlopen(
                        url + "/health", timeout=0.5
                    ) as response:
                        assert response.status == 200
                        break
                except (urllib.error.URLError, TimeoutError):
                    if time.monotonic() > deadline:
                        pytest.fail("Gunicorn did not start")
                    time.sleep(0.05)
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
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
