# MemoLens moderation service

Standalone Flask moderation for the existing Flutter `/predict` contract, backed
by **AWS Rekognition `DetectModerationLabels`**. This directory is the service
root. No Flutter changes, Firebase changes, deployment, or Git publication are
part of this preparation. This is the prepared local implementation, not a claim
that AWS moderation has been deployed or passed real-image acceptance testing.

The previous local YOLO checkpoint is **deprecated** because it produced
high-confidence false positives on benign school photos
([investigation](docs/model-quality-investigation.md)). Its loader lives in
[`legacy_yolo/`](legacy_yolo/README.md). `model.pt` stays in Git for
historical comparison only and is excluded from the Docker image.

| File | Role |
| --- | --- |
| `service.py` | Provider-agnostic Flask app: validation, SSRF-safe fetch, decode, contract |
| `rekognition_provider.py` | AWS client (timeouts, no retries), image payload, error mapping |
| `moderation_policy.py` | Version-controlled AWS label → `offensive` policy |
| `runtime.py` / `app.py` | Production startup (`app:app`) |
| `moderation_worker.py`, `gunicorn.conf.py` | Sync worker, watchdog, redacted Gunicorn logs |

Policy, failure codes, and timing: **[docs/aws-rekognition-moderation.md](docs/aws-rekognition-moderation.md)**.

## Render settings (Docker Web Service)

Use the repository containing **this prepared directory**, not the root
`server.py` in MemoLens-Server: that separate root application currently returns
an unconditional benign verdict.

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
| Instance | An always-on instance; 0.5 CPU / 512 MB is expected to be sufficient (see below) |

Startup command (Dockerfile CMD):

```sh
gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 1 app:app
```

The image no longer contains Torch, torchvision, Ultralytics, OpenCV, NumPy,
their system libraries, or the checkpoint. A local worker starts in about half a
second (YOLO warmup took about 42 seconds). Measured locally: about 55 MB RSS
after import. The measured peak was about 235 MB while re-encoding a dense
12-megapixel image, which is within 512 MB. These are local measurements, not a
Render benchmark. One worker handles one request at a time. Measure concurrency
before production traffic, and do not use a sleeping free instance.

## Environment variables

Configure these on the Render service as environment variables. Mark the two
credentials as secret, and never commit them.

| Variable | Value | Secret? |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Access key of the dedicated least-privilege IAM user | **Yes** |
| `AWS_SECRET_ACCESS_KEY` | Its secret access key | **Yes** |
| `AWS_REGION` | Rekognition region nearest the Render region, e.g. `us-west-2` for Oregon, `us-east-1` for Virginia, `us-east-2` for Ohio | No |
| `AWS_EC2_METADATA_DISABLED` | `true` (already set in the Dockerfile and by `runtime.py`) | No |
| `PORT` | Supplied by Render | No |
| `GUNICORN_CMD_ARGS` | `--config gunicorn.conf.py` (Dockerfile default) | No |

`AWS_DEFAULT_REGION` is accepted if `AWS_REGION` is absent. Do not set
`AWS_ENDPOINT_URL*`, `AWS_PROFILE`, or proxy variables. No Firebase service
account, `FIREBASE_SERVICE_ACCOUNT_JSON`, or `GOOGLE_APPLICATION_CREDENTIALS`
is needed. The backend downloads the allowlisted Firebase URL using its
download token and performs no Admin SDK operations.

Minimum IAM policy for that user (no other permissions):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "rekognition:DetectModerationLabels", "Resource": "*"}
  ]
}
```

Startup builds the AWS client locally and makes **no AWS request**. If the
region or credentials are missing, the worker logs
`aws_region_missing_or_invalid` or `aws_credentials_missing`, `/health` returns
503, and `/predict` returns 503 `moderation_unavailable`. It never approves.
Invalid (but present) credentials are detected on the first moderation call
(503 `moderation_provider_auth_failed`).

## API and safety boundaries

`POST /predict`, `Content-Type: application/json`:

```json
{"url":"<Firebase HTTPS download URL>","user_uid":"<uploader UID>","image_name":"<Storage object name>"}
```

A moderated image returns HTTP 200:

```json
{"offensive":false,"predictions":[]}
```

`predictions` items are `{"class": <AWS label>, "confidence": <0-1>, "blocking": <bool>}`.
Flutter reads only `offensive`.

The client sends no authenticated identity. `user_uid` is validated and matched
to the object path, **not trusted as proof of identity**. The backend returns a
verdict only. The existing authenticated Flutter upload cleanup handles
rejected or failed uploads. No caller-supplied identity can trigger a
privileged deletion. No rules were changed.

Only HTTPS URLs on `firebasestorage.googleapis.com`, the existing
`memories-through-lenses.appspot.com` bucket, and an exact matching
`posts/<user_uid>/<image_name>` object are accepted. The decoded object must have
exactly these three components and match both supplied fields literally. There
is no trimming, Unicode normalization, or repeated URL decoding. UIDs keep
the alphanumeric/underscore/hyphen format, maximum 128 characters. Image names
allow printable Unicode filenames up to 255 UTF-8 bytes, including historical
names such as `2026-03-11 10:34:12.468949`. The following are rejected: empty
names, surrounding whitespace, controls and non-printable characters, `/`,
`\`, `%`, and the dot segments `.` and `..`. Malformed percent escapes and
invalid UTF-8 in URL paths are rejected. Download parameters are exactly
`alt=media` and one token. The following are disallowed: redirects, userinfo,
fragments, other ports, arbitrary hosts/buckets/objects,
local/private/link-local DNS addresses, and proxy environment routing. DNS
results are checked and pinned to the TLS connection with original
hostname/certificate validation.

Valid JPEG and PNG images are accepted, up to 12 MiB and 16 million decoded
pixels, and must be at least 80 px on each side (a Rekognition minimum). The
image is re-encoded before it is sent to AWS. Source EXIF (including GPS),
JPEG comments, XMP, and ICC metadata are explicitly omitted from every encoding
attempt; image pixels are unchanged except for the documented resizing/encoding. Images stay in bounded memory.
AWS credentials exist only in the backend's runtime environment and are never
exposed to the Flutter app.

Failures return a non-2xx status with `error` (a safe machine code) and a
generated `request_id`. Unexpected exceptions do not expose their text. Logs
contain request IDs, stages, fixed codes, format-validated AWS error codes, AWS
model and policy versions, label counts, durations, and the boolean verdict
only. No request body, URL/query, user identifiers, headers, bytes, AWS
messages, or credentials are logged. No access log is enabled.

`GET /health` returns `{"status":"ok"}` with 200 once the AWS client is
configured; otherwise it returns 503 with `{"status":"unavailable"}`. It makes
no network or AWS calls. It verifies local configuration only, not IAM permission
or provider availability. Unknown labels, malformed hierarchy fields, and
missing/invalid model-version fields return 503 `invalid_moderation_result`.
A generic parent above its threshold whose returned children do not resolve
its blocking evidence returns 503 `ambiguous_moderation_result`, never approval.
Category decisions and confidence thresholds remain unchanged.

## Timing

Firebase fetch: 2-second connect/read timeouts inside a 5-second wall budget.
AWS: one attempt, 2-second connect, 3-second read, and no botocore retries. It
is not started with less than 5.5 seconds of budget left after encoding
(2 + 3 seconds plus 0.5 seconds for processing). Application budget: 11 seconds,
checked before and after moderation. Socket timeouts are not a strict total
duration bound for DNS, uploads, or slow trickles; the worker watchdog remains
necessary. Gunicorn's master kills a stuck
worker at about 13 seconds. A killed worker cannot approve later. Flutter waits
about 15 seconds and treats any failure or non-2xx response as rejection.

## Tests and checks

```sh
python -m pip install -r requirements-test.txt
python -m pytest -q tests
python -m flake8 --max-line-length 88 --extend-ignore E203 *.py legacy_yolo tests
```

The tests never contact AWS. A fixture removes any AWS credentials, config
files, and proxies from the environment and blocks every non-loopback socket
connection. Provider tests run the real boto3 client against a loopback fake of
the Rekognition endpoint. That covers signing, the no-retry configuration, read
timeouts, throttling, authentication errors, service errors, and malformed
bodies. Gunicorn tests start the real `app:app` with fake credentials and an
unreachable `AWS_ENDPOINT_URL` to show that startup makes no AWS call.

On a Docker-capable machine:

```sh
docker build -t memolens-moderation .
docker run --rm -p 127.0.0.1:10000:10000 memolens-moderation   # /health → 503 (no AWS config)
```

Docker was unavailable in the preparation environment, so the Linux image build
remains a deployment acceptance check, not a failed code check.

Before committing, include the currently new migration files as well as tracked
changes. A tracked-files-only commit would omit required Docker inputs:

- `rekognition_provider.py`, `moderation_policy.py`
- `tests/conftest.py`, `tests/test_rekognition.py`,
  `tests/test_moderation_policy.py`, `tests/test_preprocessing.py`,
  `tests/test_legacy_yolo.py`
- The complete `legacy_yolo/` archive (required by the archival unit tests,
  excluded from production)
- `docs/aws-rekognition-moderation.md`, `docs/model-quality-investigation.md`,
  `docs/model-prediction-diagnostics.json`

Keep ignored credential files untracked; no Firebase key is needed.

## Release gates before production activation

Use a separately authorized test deployment and server-side AWS credentials.
No real AWS accuracy or latency result is implied by the mocked tests.

1. Build and smoke-test the Docker image; then verify `/health` returns 200. If it returns 503, check the worker log's
   `provider_readiness` code.
2. Use `client.py` with `MODERATION_TEST_ENDPOINT`, `MODERATION_TEST_IMAGE_URL`,
   `MODERATION_TEST_USER_UID`, and `MODERATION_TEST_IMAGE_NAME` pointing at a
   consented test upload. The image URL contains a token; handle it as a secret.
3. Check known benign school photos (including the track photo from the
   investigation, swim, sports, and prom photos) return `offensive: false`.
   Check known unsafe test images return `offensive: true`. Evaluate category
   errors on representative school photos and measure end-to-end latency under
   concurrency against Flutter's 15-second deadline.
4. Check the logs show `"provider": "aws_rekognition"`,
   the actual `provider_model_version` used during acceptance, and
   `"policy_version": "memolens-school-v1"` on the `moderation` stage.
5. Check malformed input returns 400 and an unavailable image returns non-2xx.
   Reevaluate provider-model changes; logging a version is not an accuracy gate.

The service URL format is `https://<actual-render-service-name>.onrender.com/predict`.
Do not change `moderation_server_url` until acceptance passes.

References: [DetectModerationLabels](https://docs.aws.amazon.com/rekognition/latest/APIReference/API_DetectModerationLabels.html),
[moderation taxonomy](https://docs.aws.amazon.com/rekognition/latest/dg/moderation-api.html),
[Rekognition limits](https://docs.aws.amazon.com/rekognition/latest/dg/limits.html),
[Render Docker](https://render.com/docs/docker),
[Render environment variables](https://render.com/docs/configure-environment-variables),
[health checks](https://render.com/docs/health-checks).
