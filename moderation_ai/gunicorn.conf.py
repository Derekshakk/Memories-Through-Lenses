"""One sync worker owns one warmed YOLO model; no unsafe shared-model threads."""

logger_class = "moderation_worker.RedactedLogger"
worker_class = "moderation_worker.ModerationWorker"
workers = 1
threads = 1
# Upper bound for stuck DNS/native inference. A killed worker cannot approve later.
# Application soft budget is 11s; Flutter gives the HTTP request about 15s.
timeout = 13
graceful_timeout = 13
preload_app = False
backlog = 16
accesslog = None  # Never log caller-controlled paths or query strings.
errorlog = "-"
capture_output = False


def worker_abort(worker):
    worker.log.error("worker_timeout")
