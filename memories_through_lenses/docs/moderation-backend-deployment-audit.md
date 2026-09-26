# MemoLens moderation deployment audit — 2026-09-26

Investigation only. No application code, live configuration, infrastructure,
credentials, or deployment was changed. No server was started and no image was
sent to an external inference endpoint. Credential contents were not printed.

## Findings that change the restoration plan

1. The private GitHub repository `Derekshakk/MemoLens-Server` is accessible. Its
   only current branch is `main`, at `a238fc6094b24ebc70a3f7748ae3c44c8043d8d2`
   (2026-02-03). No local checkout was found in the searched user project folders.
2. Its root `server.py` combines `/predict`, `/upload_video`, and
   `/update_yearbook`. **Its active `/predict` unconditionally returns
   `offensive: false`; it does not read the image or run YOLO.** Deploying that
   entry point unchanged would violate the requirement to preserve moderation.
3. Its separate `moderation_ai/app.py` contains real YOLO inference and matches
   the Flutter request/response contract. This service can be deployed independently
   without face recognition, yearbook processing, or OpenAI.
4. The live Realtime Database configuration points all three operations at the
   same EC2 host. This strongly identifies the combined service as the intended
   historical deployment, but does not establish which revision was running there.
5. An actual production configuration and operational runbook are missing. The
   repositories do not establish a currently healthy replacement URL.

## Architecture and live evidence

Flutter uploads bytes to Firebase Storage, obtains a download URL, reads RTDB
`moderation_server_url`, then POSTs JSON:

```json
{"url":"<download URL>","user_uid":"<UID>","image_name":"<post ID>"}
```

The complete configured URL is used; the app does not append a route. HTTP 2xx
plus boolean `offensive: false` allows the Firestore write. True rejects it.
Unavailable service, non-2xx, malformed JSON or invalid schema prevent posting.

Read-only RTDB reads on this investigation returned:

| Configuration key | Configured route |
| --- | --- |
| `moderation_server_url` | `http://54.176.25.36:5001/predict` |
| `face_recognition_server_url` | `http://54.176.25.36:5001/upload_video` |
| `yearbook_server_url` | `http://54.176.25.36:5001/update_yearbook` |

Reverse DNS returns `ec2-54-176-25-36.us-west-1.compute.amazonaws.com`.
A GET to the configured `/predict` failed with OS error 61, Connection refused,
in approximately 0.03 seconds. This is a failure to establish a TCP connection,
not an inference timeout or Flask JSON error.

MemoLens-Server's committed `nohup.out` identifies Flask app `server`, the Flask
**development server**, `0.0.0.0`, private address `172.31.26.43:5001`, and an
`Address already in use` event. Root requirements include Amazon Linux/EC2 system
packages such as `aws-cfn-bootstrap`, `cloud-init`, and `ec2-hibinit-agent`.
Together these support an EC2 host running a manually managed, development-style
Flask process. They do not prove the instance was intended to be temporary or
identify why its public listener is unavailable now.

Without the AWS account/instance and logs, stopped/crashed process, changed IP,
wrong bind, or an actively rejecting network rule cannot be distinguished. A
historical log of a port conflict is not proof of the current outage's cause.
Restoring only the current root `server.py` could restore connectivity while
silently leaving moderation disabled.

## Render history and the 404

The old test client contains
`https://memories-through-lenses.onrender.com/predict`. Main-repository history
used it in January 2025, then switched the manual client back to a private LAN
address. Archived server logs show `/opt/render/project/src/...` and a Gunicorn
worker timeout in YOLO inference, followed by SIGKILL. This establishes that a
Render deployment existed; it does not prove memory exhaustion or explain its
later removal.

The historical Render URL now returns HTTP 404 with
`x-render-routing: no-server`. That points to missing routing at Render's edge,
not a healthy `/predict` Flask route returning 404. A registered POST-only Flask
route would normally answer a GET with 405. The Render account is required to
learn whether the service was deleted, renamed, or otherwise lost its hostname
mapping. It is not a verified replacement endpoint and was not selected as one.

## Repository inventory and deployment gaps

The local `moderation_ai` folder has `app.py`, `client.py`, `requirements.txt`,
`model.pt`, `model_perf.txt`, `server_error.txt`, a test JPEG, and an ignored
Firebase credential file. The image and credential contents were not opened.

MemoLens-Server has the same standalone moderation assets plus root `server.py`,
face-recognition code, logs, uploaded media, a root requirements file, and a
one-line README. No Dockerfile, Procfile, Render/Railway manifest, Cloud Functions,
startup shell script, systemd unit, environment file, or deployment instructions
were found in its current tree or the changed-file inventory of its 18 commits.
The available GitHub connector did not support deployment-history endpoints;
platform account settings were not inspected. The Flutter project's Firebase
configuration registers client apps; it does not deploy this Python service.

Important history:

- `19134b6` (2025-03-11): added `GET /` to standalone moderation.
- `f95a79d` (2025-03-12): introduced the combined service and moved the credential
  file from `moderation_ai/firebase-key.json` to repository root, without updating
  the standalone app's relative credential path.
- `fd277b0` (2026-01-29), “remove AI”: explicitly stubbed the combined `/predict`
  result and disabled its external AI implementation. Earlier revisions must
  also be audited, not assumed to implement working moderation.
- `a238fc6` (2026-02-03), “removed url”: removed active request/image-URL parsing
  from the combined `/predict`. This remains `main`.

Source references:
[standalone moderation](https://github.com/Derekshakk/MemoLens-Server/blob/a238fc6094b24ebc70a3f7748ae3c44c8043d8d2/moderation_ai/app.py),
[combined server](https://github.com/Derekshakk/MemoLens-Server/blob/a238fc6094b24ebc70a3f7748ae3c44c8043d8d2/server.py),
[remove-AI commit](https://github.com/Derekshakk/MemoLens-Server/commit/fd277b051f4d9ea537abcbc9d6e7c405106b57de).

## Model, credentials, environment and startup

| Requirement | What the current standalone code actually does |
| --- | --- |
| Model | Loads `YOLO('model.pt')` at import; path relative to process working directory |
| Model present | Yes: 6,154,974 bytes in both repositories; local and remote Git blob hashes match (`e5fa7db57f3c4d92b64ce7681dd15e695f069b75`) |
| Model validation | File identity/existence verified; loading, inference performance and moderation accuracy were not executed |
| Firebase Admin | Explicit `credentials.Certificate('firebase-key.json')`; requires this file in the working directory |
| Credential placement | Local folder has it; remote current tree has it at repository root, not beside standalone `app.py` |
| Bucket | Hardcoded `memories-through-lenses.appspot.com` |
| Permissions | Valid project service-account identity and permission to delete rejected objects in the target bucket; standalone Firestore client is created but never used for writes |
| Environment variables | No active `os.getenv`/environment-based config in standalone service |
| `GOOGLE_APPLICATION_CREDENTIALS` | Setting this alone does not override the explicit Certificate filename |
| OpenAI | No OpenAI credential needed for standalone YOLO; root combined server's OpenAI initialization is commented out |
| CORS | Unrestricted `CORS(app)`; does not authenticate requests |
| Development command | From `moderation_ai`: `python app.py` |
| Binding | `0.0.0.0:5001`, externally bindable, but ignores host-supplied `PORT` when launched directly |
| WSGI command | From `moderation_ai`: `gunicorn --bind "0.0.0.0:${PORT:-5001}" --workers 1 --threads 1 app:app` |
| Health | Local copy has no health route. Remote standalone and combined server have a static `GET /`; neither has dedicated model/inference readiness checks |

The standalone requirements file matches between repositories: Torch 2.4.1,
Torchvision 0.19.1, Ultralytics 8.3.4, Flask 3.0.3, Firebase Admin 6.5.0, and
unpinned Gunicorn among its dependencies. Use a tested Python 3.11 environment as
the starting point; do not assume compatibility with a new host's default Python.
The combined repository-root requirements are an EC2 system-environment dump
(including `rpm`, `selinux`, `dbus-python` and CPU-specific Torch wheel pins).
They should not be used as the standalone web service's cloud build manifest.

Credential-named files `firebase-key.json` and `key.json` are tracked in the
server repository/history. Contents were not inspected or reproduced. Have the
owner rotate any real credentials those files contain before reusing them, remove
secrets from tracked files/history as appropriate, and provision through secret
storage. No credential rotation or git-history change was performed here.

## Production readiness

The standalone API is deployable, but **not production-ready unchanged**:

- No request authentication/ownership verification. Caller-selected `user_uid`
  and `image_name` can determine which object an Admin credential deletes.
- Arbitrary caller URLs are fetched; redirects, internal destinations, size and
  download duration are not constrained. `requests.get` has no timeout.
- Missing/malformed fields are not fully validated; some parsing happens outside
  the try block. Raw exception text is returned to callers.
- Incoming URLs are printed, potentially exposing Storage download tokens. The
  local variant also writes every image to shared `test.jpg`; the remote variant
  has commented that write out.
- Images are resized to 64×64 before inference. The small historical validation
  report does not establish production rejection accuracy or CPU latency.
- A single global YOLO model is used. Do not add threaded inference against that
  shared object without concurrency control. Start with one synchronous worker
  for verification; size/scale with measured load. See
  [Ultralytics concurrency guidance](https://docs.ultralytics.com/guides/yolo-thread-safe-inference/).
- No dedicated readiness route, model warmup, rate/queue limits, or process
  supervision/deployment configuration is supplied.
- Rejected-image deletion failure can turn a classification into HTTP 500. The
  client still prevents publication, but deletion should be bounded/idempotent.

These are concrete source findings, not changes made in this investigation.
Authentication hardening must be coordinated with compatible Flutter requests;
the current client does not send an Authorization header to this service.

## Recommended restoration path — do not execute yet

I recommend a **paid Render Web Service for the standalone YOLO component**.
This keeps Flask/Gunicorn and the existing JSON contract, supports HTTPS and
secret files, and avoids importing the combined server's face-recognition stack
or its unconditional-approval route. This is a new deployment recommendation,
not a claim that a currently active Render production service exists.
[Render Flask deployment](https://render.com/docs/deploy-flask),
[web-service binding/HTTPS](https://render.com/docs/web-services).

Use paid, continuously available compute: free services sleep after 15 idle
minutes and can take about a minute to restart, exceeding the app's 15-second
moderation HTTP budget. Benchmark CPU inference and peak memory before choosing
instance capacity; the 6 MB checkpoint size does not measure process memory.
[Render free-service limits](https://render.com/docs/free).

Ordered operator steps:

1. Identify the EC2 instance/account from the old IP. Inspect instance state,
   public/Elastic IP, listener/process, startup mechanism and logs. Identify its
   deployed revision. Do not blindly restart the current unconditional-approval
   root server. Record separately that face/yearbook share this unavailable host.
2. Prepare a reviewed standalone moderation deployment branch: preserve real YOLO
   inference and the required response contract; fix the production-readiness
   issues above; add health/readiness and model warmup. Resolve model/credential
   paths deliberately. Do not change Flutter's moderation policy.
3. Validate a reproducible dependency build using the standalone requirements;
   pin the tested Python patch and Gunicorn version. Test CPU Torch/OpenCV runtime
   imports in the target environment rather than installing the root EC2 dump.
4. In Render, choose the reviewed MemoLens-Server branch and Root Directory
   `moderation_ai`. Build command: `pip install -r requirements.txt`. Start command:
   `gunicorn --bind "0.0.0.0:$PORT" --workers 1 --threads 1 app:app`.
   These are proposed commands, not an already validated deployment.
5. Set `PYTHON_VERSION` to the exact tested Python 3.11 patch. Render supplies
   `PORT`. Add a freshly provisioned `firebase-key.json` secret file at the
   location the app actually reads. For a native Python Render service, secret
   files are available in the service root and `/etc/secrets/`; a Docker service
   would require an explicit path change/mount. Do not assume hypothetical
   `MODEL_PATH` or `FIREBASE_STORAGE_BUCKET` variables are already implemented.
   [Python version](https://render.com/docs/python-version),
   [secret files](https://render.com/docs/configure-environment-variables).
6. Configure the readiness path once implemented. `GET /` in the remote standalone
   copy is only a basic liveness check; it does not prove classification works.
7. Verify before touching RTDB: clean start and warmup, HTTPS/readiness, valid JSON
   response for a controlled benign image, rejection of a known reject fixture,
   bounded failure on invalid/unavailable images, privacy-safe logs, and repeat/
   concurrent tests within the app's 15-second request deadline. Use isolated
   disposable Storage objects because the rejection route can delete them.
8. After explicit deployment/cutover authorization, use the actual hostname
   assigned to that verified service plus `/predict`. Expected format:
   `https://<assigned-service-hostname>/predict`, for example the host's assigned
   `onrender.com` domain or a verified custom domain. There is **no exact new
   hostname yet**. Do not use a guessed hostname or the old dead Render address.
9. Only then update `moderation_server_url` with the verified complete URL, and
   verify a real iPhone post, a rejection and a backend outage. Update face/yearbook
   configuration only as a separate verified restoration; the standalone service
   does not implement those routes.

Do not attempt to prove moderation works only by seeing `offensive: false`: the
combined stub produces that response for every input. A reject fixture and logs
confirming actual model inference are essential before cutover.

## Existing eight Flutter-side changes

Keep the five Dart code changes and the two test-file changes. They preserve the
required gate, distinguish config/HTTP/schema failures, fix misleading user-facing
advice, and test delayed photo sources/cleanup. They do not repair the server and
cannot detect a server that lies by returning unconditional approval.

Update the eighth file, the investigation document, with this audit's EC2 and
combined-server findings. Retain the temporary safe logs for device verification
and the first recovery build; after verified recovery, verbosity can be disabled
using the existing `POST_UPLOAD_LOGS=false` build flag. Do not discard the tests
or restore generic failures. Worker-local elapsed times remain local clocks;
correlate by operation ID and stage.

This audit changed documentation only. Prior verification remains 151 passing
Flutter tests and 239 baseline analyzer diagnostics; no application code changed
in this turn, so those checks were not rerun. No deployment, Firebase configuration
write, moderation-policy change, credential operation, commit or push occurred.
