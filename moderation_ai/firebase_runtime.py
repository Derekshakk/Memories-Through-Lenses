"""Firebase bootstrap. Error text must never include credential contents."""

from __future__ import annotations

import json
import os
from pathlib import Path

PROJECT_ID = "memories-through-lenses"
BUCKET = "memories-through-lenses.appspot.com"


def initialize_firebase(base_dir: Path):
    import firebase_admin
    from firebase_admin import credentials

    encoded = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    filename = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    try:
        if encoded and filename:
            raise ValueError("ambiguous credential configuration")
        if encoded:
            data = json.loads(encoded)
        else:
            if filename:
                path = Path(filename).expanduser()
                if not path.is_absolute():
                    path = base_dir / path
            elif os.environ.get("RENDER") != "true":
                # Existing ignored local-development file, relative to app.py.
                path = base_dir / "firebase-key.json"
            else:
                raise ValueError("credentials required")
            data = json.loads(path.read_text())
        if (
            not isinstance(data, dict)
            or data.get("type") != "service_account"
            or data.get("project_id") != PROJECT_ID
        ):
            raise ValueError("unexpected credential project")
        credential = credentials.Certificate(data)
        return firebase_admin.initialize_app(
            credential,
            {"storageBucket": BUCKET, "httpTimeout": 3},
            name="memolens-moderation",
        )
    except Exception:
        # Do not pass SDK or JSON parse errors (which may quote private keys) on.
        raise RuntimeError("firebase_initialization_failed") from None
