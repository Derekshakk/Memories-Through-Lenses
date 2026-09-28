FROM python:3.11-slim-bookworm

# AWS_EC2_METADATA_DISABLED: Render is not EC2; never probe instance metadata.
# AWS credentials and region are supplied only at runtime by Render env vars.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    AWS_EC2_METADATA_DISABLED=true \
    GUNICORN_CMD_ARGS="--config gunicorn.conf.py"
WORKDIR /app
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt && python -m pip check

# Explicit copies and an allowlist .dockerignore keep credentials, images, and
# the deprecated YOLO checkpoint out of the image.
COPY app.py service.py runtime.py rekognition_provider.py moderation_policy.py \
    moderation_worker.py gunicorn.conf.py ./
RUN useradd --create-home --uid 10001 moderation
USER moderation
CMD ["/bin/sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-10000} --workers 1 --threads 1 app:app"]
