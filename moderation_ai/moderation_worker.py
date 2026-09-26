"""Allow bounded model warmup without extending the inference watchdog."""

import json
import threading
import time

from gunicorn.glogging import Logger
from gunicorn.workers.sync import SyncWorker


class ModerationWorker(SyncWorker):
    def load_wsgi(self):
        stopped = threading.Event()
        startup_deadline = time.monotonic() + 90

        def startup_heartbeat():
            # No requests are accepted until load_wsgi returns. Keep the master
            # informed while importing Torch/warming YOLO, for at most 90s.
            while not stopped.is_set() and time.monotonic() < startup_deadline:
                self.notify()
                stopped.wait(0.25)

        heartbeat = threading.Thread(target=startup_heartbeat, daemon=True)
        heartbeat.start()
        try:
            super().load_wsgi()
        finally:
            stopped.set()
            heartbeat.join()
        # After startup only SyncWorker.run sends heartbeats. A blocked request
        # therefore triggers Gunicorn's normal 13s master-process watchdog.


class RedactedLogger(Logger):
    """Gunicorn exception messages can include raw request URIs or headers."""

    def error(self, msg, *args, **kwargs):
        code = (
            "worker_timeout"
            if msg == "worker_timeout" and not args
            else "gunicorn_error"
        )
        self.error_log.error(
            json.dumps({"stage": "worker", "event": "failure", "code": code})
        )

    def exception(self, msg, *args, **kwargs):
        self.error("gunicorn_exception")

    def warning(self, msg, *args, **kwargs):
        self.error_log.warning(
            json.dumps(
                {"stage": "server", "event": "failure", "code": "gunicorn_warning"}
            )
        )
