# MemoLens moderation service

Standalone Flask/YOLO moderation for the existing Flutter `/predict` contract.
This directory is the service root. No Flutter changes, deployment, database
configuration changes, or Git publication are part of this preparation.

## Render settings (recommended: Docker Web Service)

Use the repository containing **this prepared directory**, not the root
`server.py` in MemoLens-Server: that separate root application currently returns
an unconditional benign verdict. These local changes must be reviewed and made
available in the selected Git repository before Render can build them.

| Render field | Value |
| --- | --- |
| Service type | Web Service |
| Language/runtime | Docker (Dockerfile uses Python 3.11) |
| Root Directory | `moderation_ai` |
| Dockerfile Path | `./Dockerfile` (relative to Root Directory) |
| Docker Build Context | `.` (relative to Root Directory) |
| Docker Command | Leave blank; use the Dockerfile CMD |
| Health Check Path | `/health` |
| Auto-Deploy | Off until verification is complete |
| Instance | Paid, always-on CPU instance; start with at least 2 GB RAM and benchmark |

Render runs the Docker build automatically; there is no separate Build Command
field for this runtime. Inside the Dockerfile the Python build command is:

```sh
python -m pip install --no-cache-dir -r requirements.txt
```

The startup command is:

```sh
gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 1 app:app
```

The Dockerfile expands `$PORT` with a local default of 10000, installs OpenCV's
Linux libraries, uses CPU-only Torch wheels on Linux, and runs as an unprivileged
user. It deliberately copies only deployment inputs. No secret or image upload
is baked into the image. Python is constrained to the maintained 3.11 line;
`.python-version` pins 3.11.16 for local/native Python setup. Docker uses the
latest patch available under the official `3.11-slim-bookworm` tag.

Do not use a sleeping free instance: model cold startup exceeds the Flutter
request deadline. The 2 GB recommendation is an initial capacity estimate, not
a measured Render memory guarantee. One instance processes one request at a
time; concurrent queued requests can exceed the client's deadline. Measure
latency/concurrency and scale instances before sending production traffic.

## Environment and credentials

Set exactly **one** credential option:

1. Recommended: create a Render Secret File named `firebase-key.json`, containing
   a valid service account JSON for the existing `memories-through-lenses`
   Firebase project. Set `GOOGLE_APPLICATION_CREDENTIALS` to
   `/etc/secrets/firebase-key.json`. The file contents are secret; the path is not.
2. Alternatively set `FIREBASE_SERVICE_ACCOUNT_JSON` to the complete service
   account JSON using Render's environment secret controls. This entire value is
   secret. Do not echo it, put it in Git, or pass it as a Docker build argument.

Use a freshly provisioned credential: the separate MemoLens-Server repository
currently tracks credential-named `firebase-key.json` and `key.json`, and its
history includes `moderation_ai/firebase-key.json`. Their contents were not
inspected. If these are live keys, revoke/rotate them through the project owner;
removing a file from the latest commit does not revoke a leaked key. The local
`moderation_ai/firebase-key.json` is ignored/untracked and is not copied into the
image. These instructions do not rotate, remove, or expose any credentials.

Other environment settings:

| Variable | Value / source | Secret? |
| --- | --- | --- |
| `GUNICORN_CMD_ARGS` | `--config gunicorn.conf.py` (also set in Dockerfile) | No |
| `PORT` | Supplied by Render; do not hardcode 5001 | No |
| `YOLO_CONFIG_DIR` | `/tmp/ultralytics` (Dockerfile default) | No |
| `MPLCONFIGDIR` | `/tmp/matplotlib` (Dockerfile default) | No |
| `PYTHONUNBUFFERED` | `1` (Dockerfile default) | No |

The explicit Gunicorn configuration prevents a platform default from enabling
preload or unredacted access logging. Do not add `--preload`: the model is loaded
and warmed within its own worker. Credentials initialize the existing Admin SDK
for compatibility, but this verdict-only service performs **no Admin deletions,
Storage writes, or Firestore writes**. It needs no Firebase database URL or
moderation endpoint environment variable. Initialization parses/validates the
credential and project; it does not prove a key is active by making an Admin RPC.
Local development may use the ignored `firebase-key.json` next to `app.py` when
`RENDER` is not `true`. Production requires an explicit credential option.

## API and safety boundaries

`POST /predict`, `Content-Type: application/json`, body fields:

```json
{"url":"<Firebase HTTPS download URL>","user_uid":"<uploader UID>","image_name":"<Storage object name>"}
```

A processed image returns HTTP 200 and:

```json
{"offensive":false,"predictions":[]}
```

An offensive result returns the same shape with `offensive: true`. The original
five offensive classes, strictly greater than 0.7 confidence threshold, and
64-by-64 model input are preserved. Both outcomes run the real bundled YOLO
model. Empty detections are a valid benign result; failed/malformed inference is
never converted into approval.

The client sends no authenticated identity. `user_uid` is validated and matched
to the object path, **not trusted as proof of identity**. The backend returns a
verdict only. As approved, the existing authenticated Flutter upload cleanup
handles rejected/failed uploads. No caller-supplied identity can trigger a
privileged deletion. This is not a replacement for Storage/Firestore security
rules or a server-enforced posting authorization design. No rules were changed.

Only HTTPS URLs on `firebasestorage.googleapis.com`, the existing
`memories-through-lenses.appspot.com` bucket, and an exact matching
`posts/<user_uid>/<image_name>` object are accepted. UIDs/object names use the
client's alphanumeric/underscore/hyphen format, maximum 128 characters. Download
parameters are exactly `alt=media` and one token. Redirects, userinfo, fragments,
other ports, arbitrary hosts/buckets/objects, local/private/link-local DNS
addresses, and proxy environment routing are disallowed. DNS results are checked
and pinned to the TLS connection with original hostname/certificate validation.

The client currently uploads preprocessed JPEG; valid JPEG and PNG images are
accepted, up to 12 MiB and 16 million decoded pixels. Raw HEIC is not part of this
backend contract: the existing Flutter path converts photos before Storage
upload. Malformed/unsupported images fail explicitly. Images stay in bounded
memory; the old shared `test.jpg` disk write and signed-URL printing are removed.
Native iOS needs no browser CORS headers; blanket CORS was removed. Browser
clients would need a separately reviewed origin allowlist.

Failures return a non-2xx status with `error` (a safe machine code) and a generated
`request_id`: 400/415 malformed input, 413 size limit, 422 invalid image,
502 upstream fetch failure, 503 readiness/inference failure, or 504 deadline.
Unexpected exceptions do not expose their text. Logs contain generated request
IDs, stages, fixed error codes, status, durations, and the boolean verdict only.
No request body, signed URL/query, user identifiers, headers, bytes, or exception
contents are logged. No access log is enabled.

`GET /health` returns `{"status":"ok"}` with 200 only after credential bootstrap
and model load/warmup succeed; otherwise 503 with `{"status":"unavailable"}`.
It exposes no configuration or credentials and makes no network calls.

## Timing and model lifecycle

Network connect/read timeouts are 2 seconds, with a 5-second download wall budget
checked while streaming. The full application soft budget is 11 seconds.
Checks before/after decode and inference reject late results. Gunicorn's master
terminates a stuck request worker at approximately 13 seconds (plus its polling
interval); a worker that has been killed cannot approve later. A hard termination
may yield a gateway error/closed socket rather than JSON; Flutter treats either
as moderation failure. The application cannot interrupt arbitrary blocked native
code with a Python timer; the separate master-process watchdog handles that.

`ModerationWorker` is a synchronous Gunicorn worker with bounded startup
heartbeats only while importing/warming the model (up to 90 seconds, then the
normal master timeout applies). Heartbeats stop before any request is accepted.
This separates legitimate cold model startup from an inference hang. Health
routing must be enabled so traffic is not sent before warmup. Worker replacement
still causes a temporary availability gap; do not promise all failure responses
or queued traffic can finish within Flutter's approximately 15-second deadline.

`model.pt` is already Git-tracked (6,154,974 bytes), loaded relative to the Python
module rather than the working directory, and explicitly copied by Docker.
Missing weights fail readiness; no fallback model is downloaded. Only load
trusted repository checkpoints. Locally, the real checkpoint loaded and warmed
in about 42 seconds on its first run; subsequent synthetic warm inference took
about 0.05 seconds. This is not a Render or real-photo performance benchmark.

## Verification before changing Firebase configuration

Run the unit/transport/process tests from `moderation_ai`:

```sh
python -m pip install -r requirements-test.txt
python -m pytest -q tests
```

Tests mock model/Firebase behavior. Gunicorn tests start only a loopback server
and verify that slow startup survives the request watchdog and stuck inference
cannot return late approval. Runtime requirements also install the real ML stack.

On a Docker-capable machine, before deployment:

```sh
docker build -t memolens-moderation .
```

Then run the image locally with the service account supplied as a read-only mount
at `/etc/secrets/firebase-key.json` and the corresponding credential-path env
variable. Publish container port 10000 only to loopback while testing. Do not
copy a secret into the build context or paste it into a command line.

After a separately authorized deployment, verify `/health` returns 200, then use
`client.py` with environment values `MODERATION_TEST_ENDPOINT`,
`MODERATION_TEST_IMAGE_URL`, `MODERATION_TEST_USER_UID`, and
`MODERATION_TEST_IMAGE_NAME` pointing at a consented test upload. The image URL
contains a token and must be handled as a secret. The script prints only HTTP
status and a verdict. Verify a known benign and known offensive example against
the real model, malformed input (400), and unavailable image (non-2xx); confirm
there are no automatic approvals on failure. Measure warm and concurrent latency
on the purchased instance and inspect stage logs. Clean up test uploads through
the authenticated client/owner, not this backend.

The eventual URL format is `https://<actual-render-service-name>.onrender.com/predict`
or the verified custom domain's `/predict`. Use the exact assigned deployment URL
only after verification; do not guess it or change `moderation_server_url` now.

The Python 3.11 suite and local real-model smoke test passed during preparation.
Dependency resolution also succeeded for Linux x86_64/Python 3.11, including the
CPU-only Torch and torchvision wheels.
Docker was unavailable in the preparation environment, so the Linux image build,
Render startup/secret mounting, live Firebase fetch, real-photo accuracy, and
production capacity remain deployment acceptance checks. No deployment occurred.

References: [Render Docker](https://render.com/docs/docker),
[secret files](https://render.com/docs/configure-environment-variables),
[health checks](https://render.com/docs/health-checks), and
[free-instance limitations](https://render.com/docs/free).
