# DEPRECATED: local YOLO moderation checkpoint

**Not used in production.** The production `/predict` path uses AWS Rekognition
(`rekognition_provider.py`, `moderation_policy.py`). This directory keeps the
old checkpoint loader only for historical comparison and investigation.

The checkpoint `../model.pt` stays in Git for that purpose but is excluded from
the Docker image by `../.dockerignore`. It produced high-confidence false
positives on benign school photos even after the preprocessing fix; see
[the investigation](../docs/model-quality-investigation.md).

To run the old model locally (never in production):

```sh
python -m pip install -r requirements.txt -r legacy_yolo/requirements.txt
MODERATION_ACCEPTANCE_MANIFEST=/private/fixtures.json \
    python -m pytest -q legacy_yolo/test_legacy_acceptance.py
```

`legacy_yolo.yolo_checkpoint.LegacyYoloProvider` implements the same provider
interface as production, with the historical rule (any of `adult`, `racism`,
`substance`, `violence`, `weapons` above 0.7 confidence).
