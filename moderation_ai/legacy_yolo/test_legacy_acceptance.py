"""DEPRECATED opt-in YOLO release gate, kept for historical comparison only.

Not collected by `pytest tests`. Run explicitly from moderation_ai with the
legacy requirements installed:
MODERATION_ACCEPTANCE_MANIFEST=/private/fixtures.json \\
    python -m pytest -q legacy_yolo/test_legacy_acceptance.py
"""

import json
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT), str(ROOT / "tests")]


@pytest.mark.skipif(
    not os.environ.get("MODERATION_ACCEPTANCE_MANIFEST"),
    reason="No labeled real-image acceptance manifest supplied",
)
def test_legacy_model_labeled_acceptance_manifest():
    from legacy_yolo.yolo_checkpoint import LegacyYoloProvider, load_model
    from service import create_app
    from test_service import payload

    manifest = Path(os.environ["MODERATION_ACCEPTANCE_MANIFEST"]).resolve()
    cases = json.loads(manifest.read_text())["cases"]
    assert isinstance(cases, list) and cases, "Acceptance cases are required"
    provider = LegacyYoloProvider(load_model())
    mismatches = []
    for index, case in enumerate(cases):
        assert isinstance(case["offensive"], bool)
        assert isinstance(case["path"], str) and "://" not in case["path"]
        fixture = Path(case["path"])
        if not fixture.is_absolute():
            fixture = manifest.parent / fixture
        data = fixture.read_bytes()
        app = create_app(provider=provider, fetcher=lambda *_: data)
        response = app.test_client().post("/predict", json=payload())
        if (
            response.status_code != 200
            or response.json.get("offensive") is not case["offensive"]
        ):
            mismatches.append(
                {
                    "case_index": index,
                    "expected_offensive": case["offensive"],
                    "status": response.status_code,
                    "actual_offensive": response.json.get("offensive"),
                }
            )
    # Only case indices and verdicts; no fixture paths, images, or request URLs.
    assert not mismatches, json.dumps(mismatches)
