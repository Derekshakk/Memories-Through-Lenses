FROM python:3.11-slim-bookworm

# OpenCV's existing non-headless wheel requires these Linux shared libraries.
RUN apt-get update && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    YOLO_CONFIG_DIR=/tmp/ultralytics \
    MPLCONFIGDIR=/tmp/matplotlib \
    GUNICORN_CMD_ARGS="--config gunicorn.conf.py"
WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt && python -m pip check

# Explicit copies and an allowlist .dockerignore keep credentials/images out.
COPY app.py service.py runtime.py firebase_runtime.py moderation_worker.py gunicorn.conf.py model.pt ./
RUN useradd --create-home --uid 10001 moderation
USER moderation
CMD ["/bin/sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-10000} --workers 1 --threads 1 app:app"]
