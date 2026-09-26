"""WSGI entry point: gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 1 app:app."""

from runtime import build_app

app = build_app()
