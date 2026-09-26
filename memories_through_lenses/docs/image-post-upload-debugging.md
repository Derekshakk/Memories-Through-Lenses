# Released iOS photo-post failure: investigation, 2026-09-25

**2026-09-26 follow-up:** The [backend deployment audit](moderation-backend-deployment-audit.md) identifies MemoLens-Server, EC2 evidence, and an unconditional-approval route in its combined server. It supersedes the earlier unknown-backend/deployment findings below.

## Finding and limits

**Posting is not yet repaired in production.** The currently configured external
moderation endpoint refuses TCP connections. Restoring that service (or supplying
its verified replacement endpoint) is required. Local changes below add precise
diagnostics and regression coverage; they do not make an unavailable service work.

Read-only checks from this environment on 2026-09-25:

- GET of the `moderation_server_url` child in the project's default Realtime
  Database returned HTTP 200 and an HTTP endpoint on port 5001, path `/predict`.
- A GET to that exact configured endpoint failed with OS error 61,
  **Connection refused**, in approximately 0.04 seconds. No image, user ID,
  download URL, token, or credential was sent. This is a transport failure,
  before HTTP status/JSON/inference, not a slow image decode.
- The legacy database hostname returned 404. The installed iOS Firebase SDK's
  default `projectID-default-rtdb.firebaseio.com` fallback selects the working
  database. Neither Dart Firebase options nor the iOS plist explicitly includes
  a database URL, but that omission is **not** a demonstrated defect here.
- No production phone trace, server process logs, deployment access, or
  physical iPhone was available. A current refusal does not prove the exact
  socket error at the time of the reported phone attempt, nor whether its cause
  is a stopped process, incorrect listener, firewall rejection, or stale endpoint.

## Moderation architecture, configuration and deployment

The active URL is **not defined by a source-file constant**. It is the string at:

- Realtime Database: `memories-through-lenses-default-rtdb.firebaseio.com`
- Child: `moderation_server_url`
- Value observed: `http://54.176.25.36:5001/predict`

`FirebasePostBackend.moderate` in `lib/services/firebase_post_backend.dart`
loads this value via `_sideCall`; it uses the full URI verbatim, rather than
appending `/predict`. The released app reads it for every new photo submission
that has successfully uploaded and obtained its download URL. Missing/empty
configuration historically skips moderation, but **the live value is configured**,
and the current app requires its affirmative result before writing the post.
No configuration has been changed or removed during this investigation.

Request: HTTP POST, `Content-Type: application/json`:

```json
{"url":"<Storage download URL>","user_uid":"<signed-in UID>","image_name":"<preallocated post ID>"}
```

Success requires HTTP 2xx and JSON containing a boolean `offensive`:

```json
{"offensive":false,"predictions":[{"class":"<label>","confidence":0.1}]}
```

The Flutter client uses only `offensive`. True rejects the post. Missing/non-boolean
values, invalid JSON, HTTP errors and transport failures are not approval.
The server may delete `posts/<user_uid>/<image_name>` when offensive is true.
It returns `{"error":"..."}` with HTTP 400 or 500 on server failures.

Repository searches covered tracked and untracked source/configuration files,
backend directories, environment/deployment filenames, and available git history.
Generated build artifacts and dependency caches were excluded from source scans;
the relevant installed native plugin/SDK implementation was inspected separately.

Findings:

- `moderation_ai/app.py` is the backend, with `app = Flask(__name__)` and
  `@app.route('/predict', methods=['POST'])`. `model.pt` and `requirements.txt`
  are present. Last modification of `app.py` in available history is January 9,
  2025. It is a sibling of the Flutter project, not a Firebase Cloud Function.
- No checked-in deployment manifest, Dockerfile, Procfile, service definition,
  environment file, Cloud Functions implementation, or production runbook was
  found. Current `firebase.json` is FlutterFire platform registration metadata,
  not a backend deployment definition.
- The active numeric IP does not occur in source or available git history.
  There is **no evidence establishing that particular IP was a development host**,
  nor any record identifying its machine owner or deployment method.
- `moderation_ai/client.py` is a manual test client. January 9, 2025 history used
  `https://memories-through-lenses.onrender.com/predict`; January 16 changed the
  actual request back to a private LAN IP, keeping the unused Render variable.
  A read-only GET to that Render `/predict` URL now returns 404. It is an older
  deployment reference, not a verified newer production endpoint.
- `lib/services/servers.dart` contains `http://localhost:5000` and another
  face-recognition host. Its `Servers.checkImage` has no callers in `lib/`, uses
  a different payload/parser, and is not the current posting implementation.
  Its localhost constant cannot repair the deployed moderation service.
- `facial_recognition_ai/main.py` is a local video/photo face-recognition script,
  not the Flask moderation HTTP service or a replacement endpoint.

What the local server requires to run (inferred from its actual entry points,
not a claim about the unknown existing deployment):

1. Work from the `moderation_ai` directory: both `model.pt` and
   `firebase-key.json` are relative paths resolved at import time.
2. Install `requirements.txt` in an isolated Python environment; the historical
   server trace uses Python 3.11. Dependencies include Flask, Gunicorn,
   Ultralytics, Torch, Pillow, Requests and Firebase Admin.
3. Supply the Firebase Admin credential file securely. Its contents were not
   inspected or printed; it is excluded by the repository's `.gitignore`.
   The code selects Storage bucket `memories-through-lenses.appspot.com`.
4. `python app.py` starts Flask's development listener on `0.0.0.0:5001`.
   Gunicorn is included as a dependency; the WSGI target is `app:app`.
   An operator could serve it with
   `gunicorn --bind "0.0.0.0:${PORT:-5001}" app:app` from that directory,
   behind their production networking/TLS setup. This is a derived entry-point
   command, not a recovered production deployment command. Nothing was launched.
5. Verify model loading, memory/latency, listener reachability, and a controlled
   POST before treating the service as recovered. The archived worker timeout
   means process startup alone is insufficient proof of reliable inference.

Restoration means locating the deployment for the configured IP and restoring
its service/listener, or deploying the existing backend at a verified managed
endpoint and then deliberately updating `moderation_server_url`. Neither action
can be completed here without server access or an approved verified endpoint.

## Exact source of the reported message

In released commit `296ce05`, `lib/services/post_creation.dart`,
`PostCreationFailure.message` maps only `moderation` to `checking your photo`,
then interpolates:

> Could not finish checking your photo. Check your connection and try again. If the photo is unavailable, select it again.

The literal full sentence is not stored contiguously in Dart source.
`lib/screens/create_post.dart`, `_CreatePostScreenState._sharePost`, assigns
`failure.message` to `_message`; `build` displays it with `Text(_message)`.

The call chain is:

`_sharePost` → `PostCreation.submit` → `_run` →
`_step('moderation', backend.moderate)` → `FirebasePostBackend.moderate` →
`_sideCall(..., mustSucceed: true)`.

The exact message proves that local byte acquisition, preprocessing, Storage
upload completion, and download URL retrieval **already succeeded** for that
submission. Firestore `writePost` has **not** been dispatched. It does not mean
local validation, Photos/iCloud downloading, or image compression failed.

## Every route through the released moderation failure handling

| Operation | Released behavior / message |
| --- | --- |
| HTTP client factory throws | Escapes into `_step('moderation')`; generic checking message; factory was outside the local try/finally |
| RTDB `ref(...).once()` or snapshot access throws | Generic checking message, except Firebase auth/permission codes use session/group messages |
| RTDB read exceeds 15 seconds | Checking message **with `(timed out)`**, unlike the reported exact text |
| Config value absent/empty | Returns success with `not_configured`; no HTTP call, no checking failure |
| Malformed configured URL, connection refused, DNS/TLS/socket/client error | Generic checking message; no timeout suffix for immediate errors |
| HTTP POST exceeds 15 seconds | Checking message with `(timed out)`; client closed in finally |
| HTTP status outside 200–299 | Throws `post_moderation/http-NNN`; generic checking message |
| Successful HTTP body is malformed JSON | `FormatException`; generic checking message |
| JSON is not a map or `offensive` is missing/not boolean | `post_moderation/invalid-response`; generic checking message |
| Boolean `offensive: true` | **Different** message: photo not approved; service may delete the image |
| Boolean `offensive: false` | Moderation succeeds, then session check and Firestore write |
| Outer moderation stage exceeds 35 seconds | Checking message with `(timed out)` |
| Explicit cancellation during moderation | `StateError('canceled')`; generic checking failure internally; disposed screen does not render it |

`_run` previously flattened all those causes to stage `moderation`. Error type
was retained, but config/HTTP/response context was not propagated to the UI.
The new implementation preserves `moderation_config`, `moderation_http`, or
`moderation_response` with the original cause. Outer deadline/cancellation
remains identifiable as `moderation`.

On failure before Firestore dispatch, `_cleanUpload` runs bounded cancellation
then deletion, each at most five seconds. Successful Storage tasks are not
canceled, but their object is deleted. Cleanup errors are logged and never
replace the original failure. `_sharePost` clears uploading in `finally`, permits
a fresh attempt for a definite failure, and never navigates. Pending Firestore
writes retain the same submission to avoid duplicate posts; this is unrelated to
moderation failure, since no write exists yet.

## Why this appeared after previous fixes

- `ff0c15f`: background compression and best-effort moderation; failed moderation
  did not block posting. Original-file fallback could bypass processing limits.
- `0be558e`: retained image bytes, strict preprocessing, separate bounded stages,
  Firestore write tracking, and **changed moderation to `mustSucceed: true`**.
  This introduced the current message and made service unavailability block posts.
- `574f8cf`: group guards, late Storage cleanup, cancellation-race handling and
  tests; it did not introduce the moderation label or required gate.
- `296ce05`: release preparation; no photo-pipeline changes.

The required gate exposes the service outage. Reverting to blind best-effort
posting would not be a service repair: `moderation_ai/app.py` can delete the image,
so ignoring its result can publish an image that the service subsequently removes.
No moderation bypass has been added. No timeouts were increased. Cancellation
is not an explanation for the observed immediate refusal.

The sibling server source implements the expected JSON contract. It downloads
Storage bytes with `requests.get`, checks content type, decodes using Pillow,
resizes to 64×64, runs YOLO, and returns boolean `offensive`. Server exceptions
return HTTP 500. It also writes `test.jpg` and logs the incoming image URL.
Those server logging/processing behaviors were inspected, not executed or changed.
An archived January 2025 server log shows a Gunicorn worker timeout during YOLO
inference; it is historical evidence only, not evidence for this incident.

## Complete photo-path audit

1. Gallery/camera selection: `image_picker` uses 1920×1920 maximum dimensions,
   quality 90. The native picker future has a two-minute deadline including user
   interaction and materialization. CameraScreen also has a separate 30-second
   capture bound, handing a temporary File through UserProvider to Create Post.
2. Installed `image_picker_ios 0.8.12+2`: PHPicker asynchronously calls
   `loadDataRepresentationForTypeIdentifier(UTTypeImage)`, creates a UIImage,
   scales it and writes its own app temporary file **before** returning XFile.
   This path supports HEIC/HEIF and Live Photo still representations. UIKit
   converts non-PNG/non-GIF formats to JPEG. PNG stays PNG. This is not an
   NSItemProvider file URL used after its completion handler has deleted it.
3. Create Post immediately calls XFile `length()` (10-second bound), then
   `readAsBytes()` (15-second bound), storing a Uint8List for preview and upload.
   `cross_file` on iOS implements these using File operations; XFile itself does
   not confer permanent access or perform an additional iCloud asset download.
   No File.exists or decodeImageFromList call exists on this posting path.
   The metadata read is redundant for availability, but enforces a size cap
   before allocation; it is not implicated in this message. It remains unchanged.
4. Reading an unavailable source produces **Could not open this photo**, not the
   reported checking message. Deleting the source after acquisition does not
   affect submission. A separate-camera handoff can still lose its file before
   acquisition; it fails recoverably and is tested, not claimed impossible.
5. `ImageUtils.prepareBytes`: `compute` executes validation, decode, EXIF rotation
   and mirroring, resizing and encoding on a worker isolate on iOS/Android.
   Limits: 60 MiB input, 64 million pixels, 1920-pixel output edge, JPEG quality 85.
   Compact PNGs remain PNG when smaller. High-resolution camera photos are decoded
   there; gallery photos have already been scaled natively. The Dart image codec
   does not decode raw HEIC: the supported iOS picker converts it first. An
   artificially supplied unconverted HEIC is rejected at preprocessing, with a
   **different** message. No new rejection of normal iPhone formats was introduced.
6. Preprocessing's 25-second bound can fail a slow job. `Future.timeout` does not
   terminate its worker; a late result cannot initiate upload. Tests cover both
   slow success and late completion after timeout. There is no evidence that this
   deadline produced the reported message, so it has not been changed speculatively.
7. Auth/group validation, `putData` with matching MIME type, task completion,
   `getDownloadURL`, required remote moderation, auth recheck, `post.set`, loading
   cleanup and navigation follow in order. Storage has a two-minute bound;
   URL/auth/group/write waits have 25-second bounds. The six-minute UI watchdog
   is a separate final bound. It would produce a different failure label.

Apple documents asynchronous asset loading and image_picker documents physical
HEIC device testing: [Apple Photos selection](https://developer.apple.com/documentation/photokit/selecting-photos-and-videos-in-ios),
[Flutter image_picker](https://pub.dev/packages/image_picker).
Native behavior above was checked against the **installed** plugin source, not
assumed from the current package release.

## Changes and diagnostic markers

- `lib/services/post_trace.dart`: shared temporary diagnostics with operation ID,
  stage, event, elapsed time, and uppercase marker. No raw exception messages,
  URLs, captions, image bytes, credentials or response bodies are logged.
- `lib/services/image_utils.dart`: validation, decode and compression start,
  success and failure markers inside the worker. Processing itself is unchanged.
  Worker elapsed time starts at worker entry; correlate by operation ID and stage.
- `lib/screens/create_post.dart`: PHOTO_PICKED, separate length and byte-read
  markers, failure stage in UI diagnostics, injectable picker for deterministic
  delayed-source tests. No UI layout changes.
- `lib/services/firebase_post_backend.dart`: distinguish config, transport/status,
  and response-contract errors; validate endpoint shape; close clients on all
  request outcomes. The existing 15-second deadline is injectable for tests.
- `lib/services/post_creation.dart`: preserve detailed remote failure stage/cause;
  describe service unavailability instead of implying a bad photo. Rejections
  remain explicit. No change to approval policy or cleanup/write sequencing.

Expected trace: PHOTO_PICKED → PHOTO_BYTES_READ_START/SUCCESS →
PHOTO_VALIDATION_START/SUCCESS → PHOTO_DECODE_START/SUCCESS →
PHOTO_COMPRESSION_START/SUCCESS → STORAGE_UPLOAD_START/SUCCESS →
DOWNLOAD_URL_START/SUCCESS → MODERATION_CONFIG_START/SUCCESS →
MODERATION_HTTP_START → MODERATION_HTTP_FAILURE (or TIMEOUT / response status) →
cleanup → UI_IDLE. A successful moderation response continues to
POST_WRITE_START/SUCCESS and navigation.

## Verification and remaining work

Tests in `test/firebase_post_backend_test.dart` reproduce refused connections
only after successful upload/URL retrieval, RTDB denial, config/HTTP timeouts,
invalid endpoint values, malformed response contracts, and log redaction.
`test/create_post_upload_test.dart` adds delayed iCloud-style materialization,
delayed in-memory XFile reads, read deadlines/late results, slow preprocessing,
processing deadlines/late results, and loading cleanup across backend failures.
Existing tests cover JPEG, PNG screenshots, large images, all eight EXIF
orientations, deleted/unavailable temporary files, Storage errors, Firestore
errors, pending acknowledgments, cleanup and navigation failures.

No Firebase rules, project settings, bundle identifier, signing, deployment
target, app version or build number changed. No commits, pushes or deployments.

To complete the production repair, restore the configured server listener and
verify a valid moderation POST with a controlled non-private test image returns
2xx and boolean `offensive: false`. Then verify the entire post on a physical
released-style iPhone build, including iCloud-only HEIC, Live Photo stills, large
camera captures, screenshots, rotation, offline failure and retry. Synthetic
Dart tests do not reproduce Photos download scheduling, device memory pressure,
native HEIC conversion, or the phone's specific network route. Server recovery
and an actual device run have not been verified.

Validation completed in this workspace:

- `dart format .`: passed; 56 Dart files processed in the final pass.
- `flutter test`: **151 tests passed**.
- `flutter analyze`: exits nonzero with **239 pre-existing diagnostics**
  (0 errors, 10 warnings, 229 infos). A separate HEAD snapshot with unchanged
  local Firebase options/assets produces the same diagnostics; no new issues.
- `git diff --check`: passed.
