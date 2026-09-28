# Moderation false-positive investigation — 2026-09-27

> **Historical investigation (2026-09-27):** the prepared local production
> entrypoint now uses AWS Rekognition; this is not a deployment claim
> (see [aws-rekognition-moderation.md](aws-rekognition-moderation.md)). The YOLO
> checkpoint below is deprecated, kept in `../legacy_yolo/` and `../model.pt`
> for historical comparison only, and excluded from the Docker image.

**Release blocked.** Correcting preprocessing does not make the supplied benign
school track photo pass. No model replacement, threshold increase, class bypass,
image-specific exception, Firebase change, or deployment has been performed.

## Findings supported by reproduction

1. The local checkpoint reproduces the deployed `substance` result almost exactly:
   class ID 2, confidence 0.9587165713 (production 0.9587166905), full-image box.
   `pred.cls`, `pred.conf`, and `model.names[int(pred.cls)]` are used correctly.
   There is no index offset, separate stale label file, or confidence normalization
   bug in the Flutter/backend postprocessing path.
2. The backend squashed 1170x646 pixels to 64x64 before YOLO enlarged/letterboxed
   them to its 640-pixel network input. This destroys detail and changes aspect
   ratio; it does not make the network operate at 64 pixels. The checkpoint was
   trained with `imgsz=640`. Commit `465c836` introduced a 320x320 pre-resize;
   commit `0563790` reduced it to 64x64 on 2025-01-09.
3. Removing the destructive pre-resize changes the track image's prediction to
   class ID 3 (`violence`) at 0.9835975766. Full 640x640 letterbox padding also
   rejects it (`violence`, 0.9861139655). The false positive therefore persists
   with standard, detail-preserving YOLO preprocessing. It is a checkpoint
   generalization/calibration failure in addition to a preprocessing defect.
4. Arbitrary square resizing to 320 or 640 happens to bring this image's unsafe
   detections below 0.7, but distorts aspect ratio and has no supporting recall
   evidence. It was evaluated diagnostically and **not adopted** as a fix.
5. The repository flower image is also falsely rejected as `substance` with the
   legacy pre-resize; normal native-aspect inference returns no unsafe class over
   0.7. This is one observed improvement, not proof of production accuracy.

The root reason the trained checkpoint learned these false associations cannot
be established without its training examples, annotations, and held-out data.
Label correctness against training ground truth is unverified; **the code's
mapping agrees exactly with the checkpoint's own metadata**. We have not claimed
to prove that the training data itself was labeled correctly.

## Artifact, class schema, and inference configuration

- File: the module-relative `moderation_ai/model.pt`, unchanged.
- SHA-256: `e7a63a36826462e2f0594e5aa7ad7e9d5999835fac26361f1b89d9d951de173a`.
- Git blob: `e5fa7db57f3c4d92b64ce7681dd15e695f069b75`, identical to
  MemoLens-Server's `moderation_ai/model.pt` at the time of inspection.
- Parent repository history contains one checkpoint addition (`b64ac7a`), with
  no alternative intended checkpoint found. The deployed numerical reproduction
  is strong evidence of the same model, but no remote filesystem/hash inspection
  was performed.
- Checkpoint date: 2024-08-06; training library: Ultralytics 8.2.74;
  current pinned runtime: Ultralytics 8.3.4 / Torch 2.4.1.
- Architecture: YOLOv8n detection model (`yolov8n.yaml`), six output classes,
  strides 8/16/32. Training metadata: 640-pixel size, 500 epochs, batch 16,
  `single_cls=False`, `rect=False`, `classes=None`.

| Class ID | Checkpoint name | Policy |
| --- | --- | --- |
| 0 | adult | Reject above 0.7 |
| 1 | racism | Reject above 0.7 |
| 2 | substance | Reject above 0.7 |
| 3 | violence | Reject above 0.7 |
| 4 | weapons | Reject above 0.7 |
| 5 | none | Does not override an unsafe detection |

RGB/PIL handling was correct. The installed Ultralytics loader converts PIL RGB
to its internal BGR array; its predictor converts back to RGB tensors and divides
by 255 once. Its native `LetterBox` preserves aspect ratio and pads to stride.
There was no channel swap or double normalization to fix. The track image's
EXIF orientation is 1, so orientation does not explain this particular result.
Orientation correction was added for other valid iPhone images.

The detection results below are **all returned post-NMS boxes**, including their
unmodified class IDs and floating-point confidences; they are not fabricated
policy scores. YOLO's existing 0.25 detection reporting threshold remains
unchanged. The application still rejects any supported unsafe class strictly
above 0.7. No heuristic ignores large/full-image boxes: doing so could hide real
unsafe detections from this checkpoint.

## Exact track-image results

| Preprocessing | Class ID / name | Confidence | Box `[x1,y1,x2,y2]` |
| --- | --- | --- | --- |
| Legacy 64x64 square | 2 / substance | 0.9587165713 | `[0,0,64,63.5975647]` |
| Diagnostic 320x320 square | 3 / violence | 0.6882988811 | `[0,0,320,319.6393433]` |
| Diagnostic 320x320 square | 5 / none | 0.5883474946 | `[0,0,320,320]` |
| Diagnostic 640x640 square | 3 / violence | 0.6747475863 | `[0,0,640,640]` |
| Diagnostic 640x640 square | 5 / none | 0.2938660383 | `[0,0,640,634.5454102]` |
| Native aspect, 640 target | 3 / violence | 0.9835975766 | `[0,0,1169.8133545,646]` |
| Diagnostic fixed 640 letterbox | 3 / violence | 0.9861139655 | `[0,142.3296204,638.1632080,496.3595886]` |

Coordinates refer to each case's supplied image. No other boxes were returned
for these calls. Complete legacy/corrected outputs for the four benign fixtures
are in [model-prediction-diagnostics.json](model-prediction-diagnostics.json).
No private image, download token, user identity, or signed URL is stored there.

## Changes prepared locally

- `service.py`: retain decoded image dimensions/detail; EXIF-transpose and convert
  to RGB; explicitly request YOLO `imgsz=640`. Existing byte/pixel limits,
  deadlines, URL binding, SSRF restrictions, and moderation threshold stay intact.
- `runtime.py`: warm up at the explicit checkpoint inference size; require the
  supported six-class schema. No weights or label IDs were rewritten.
- Unsupported result labels now fail explicitly, rather than silently falling
  outside the unsafe-class set and potentially approving an unreviewed model.
- Added regression tests for retained pixels/aspect/color, orientation, inference
  size, all five unsafe-class thresholds, and refusal of unknown labels. A high
  `none` score cannot override a simultaneous unsafe score.
- Added an opt-in real-model acceptance test using a private local manifest. It
  fails on the supplied track photo. Missing fixture configuration is reported
  as a skip, not a model-accuracy pass. Known-positive coverage is also required
  before this can serve as a release acceptance gate.

## Measured outcomes and limitations

| Benign fixture | Legacy decision | Corrected decision |
| --- | --- | --- |
| Supplied school track photo | Reject | **Reject (false positive remains)** |
| Repository flower photo | Reject | Approve |
| Synthetic blue PNG | Approve | Approve |
| Synthetic color gradient PNG | Approve | Approve |

This tiny diagnostic set has two real photographs and two synthetic images. It
is not a representative accuracy benchmark. Local corrected inference took
approximately 25–92 ms, excluding startup/network and without Render hardware.
Local `/predict` calls using the real checkpoint confirmed these four decisions.

Both available repositories were inspected for training code, dataset YAML,
annotations, alternative checkpoints, and known-positive moderation fixtures.
None were available. `model_perf.txt` reports only **24 validation images**, with
23 annotated instances and one background; only four or five positive images per
unsafe class and reported aggregate precision 0.731. That report is not evidence
of low false-positive rates on school photos and does not supply reproducible
positive fixtures. Mocked threshold tests cannot establish real unsafe-image
recall.

## Required before a production release

Obtain the original `image-ai` training project and dataset/label configuration,
or a separately validated replacement checkpoint with the same reviewed schema.
Check annotation-to-class-ID correspondence, add representative benign school,
sports, outdoor, and flower negatives, and evaluate independent positive images
for all five unsafe classes. Retrain/calibrate using separate training,
validation, and held-out acceptance sets. Determine thresholds from measured
precision/recall and the product's error requirements, not this single image.

The safest current policy is to keep failing closed on supported unsafe scores
and processing uncertainty. Neither disabling `substance`/`violence`, trusting a
competing `none` score, filtering full-image boxes, nor raising the threshold is
justified by the evidence. There is no evidence-backed local policy adjustment
that safely approves this image while preserving unsafe-content recall.

The preprocessing correction is ready for review as an isolated code defect
fix. **This is not ready to redeploy as the completed photo-posting fix.** The
track photo still fails, no true-positive acceptance set is available, and a
quality-validated checkpoint is still needed. No deployment, Git commit/push,
Firebase change, or Flutter modification was performed.

References: installed Ultralytics 8.3.4 `data/loaders.py`,
`engine/predictor.py`, `data/augment.py`, and
[`models/yolo/detect/predict.py`](https://github.com/ultralytics/ultralytics/blob/v8.3.4/ultralytics/models/yolo/detect/predict.py);
[official prediction input/preprocessing documentation](https://docs.ultralytics.com/modes/predict/).
