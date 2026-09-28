# AWS Rekognition moderation: policy and operations

The prepared production `/predict` entrypoint uses AWS Rekognition `DetectModerationLabels` (content
moderation model version 7 taxonomy). The mapping from AWS labels to the
MemoLens `offensive` boolean is `moderation_policy.py`, policy version
`memolens-school-v1`. Changing it is a reviewed code change. Environment
variables cannot change thresholds. Deployment and real AWS acceptance remain
separate release gates; the local test suite uses simulated provider responses.

## Request flow

1. Validate `url`, `user_uid`, `image_name` (exact host, bucket, `posts/<uid>/<name>`
   object identity, traversal, query, and encoding rules). No change.
2. Fetch the image server-side from Firebase Storage with DNS pinning, no
   redirects, no proxies, 12 MiB and 5-second limits. No change.
3. Decode it as JPEG or PNG (16 MP limit), apply EXIF orientation, convert to RGB. No change.
4. Re-encode as JPEG, explicitly stripping source EXIF/GPS, JPEG comments,
   XMP, and ICC metadata on each attempt. Longest
   side at most 4096 px (2048 px fallback), quality 90, 80 or 70, at most 5 MB.
   Images under 80 px on either side are rejected (422 `image_too_small`)
   because Rekognition does not accept them.
5. Call `DetectModerationLabels` with `MinConfidence=50` and **one attempt**
   (no retries): 2 s connect timeout, 3 s read timeout. The call is skipped
   (504) if less than 5.5 s of the 11 s request budget remains after encoding.
   This reserves the 2 + 3 s nominal network budget and 0.5 s processing margin.
6. Validate the raw response shape before botocore parses it. Validate every
   label (reviewed name, finite confidence 0-100, exact parent and integer
   taxonomy level). Require a valid model-version string, including for empty
   results. Unknown labels or malformed fields fail with 503. Apply the policy.
7. Return `{"offensive": bool, "predictions": [...]}`.

## Policy

Confidence is AWS's percentage. A label **blocks** when its confidence is at
least the threshold. Any blocking label makes the photo `offensive: true`.

| AWS label (L1 → L2 → L3) | Decision | Threshold |
| --- | --- | --- |
| Explicit, Explicit Nudity, Exposed Male/Female Genitalia, Exposed Buttocks or Anus, Exposed Female Nipple, Explicit Sexual Activity | Block | 60 |
| Sex Toys | Block | 70 |
| Implied Nudity | Block | 80 |
| Obstructed Male Genitalia | Block | 85 |
| Non-Explicit Nudity of Intimate parts and Kissing, Non-Explicit Nudity, Bare Back, Exposed Male Nipple, Partially Exposed Buttocks, Partially Exposed Female Breast, Obstructed Intimate Parts, Obstructed Female Nipple, Kissing on the Lips | Allow | – |
| Swimwear or Underwear, Female Swimwear or Underwear, Male Swimwear or Underwear | Allow | – |
| Violence *(generic)*, Graphic Violence *(generic)* | Block | 80 |
| Weapons | Block | 85 |
| Weapon Violence, Self-Harm | Block | 60 |
| Blood & Gore | Block | 70 |
| Physical Violence | Block | 90 |
| Explosions and Blasts | Block | 90 |
| Visually Disturbing *(generic)*, Crashes *(generic)*, Emaciated Bodies, Air Crash | Block | 80 |
| Death and Emaciation *(generic)* | Block | 70 |
| Corpses | Block | 60 |
| Drugs & Tobacco *(generic)*, Products *(generic)* | Block | 80 |
| Pills | Block | 90 |
| Drugs & Tobacco Paraphernalia & Use, Smoking | Block | 70 |
| Alcohol *(generic)* | Block | 80 |
| Alcohol Use, Drinking | Block | 70 |
| Alcoholic Beverages | Block | 85 |
| Rude Gestures, Middle Finger | Block | 80 |
| Gambling | Block | 85 |
| Hate Symbols, Nazi Party, White Supremacy, Extremist | Block | 60 |
| Any unknown label, including under a known parent | Fail explicitly (503) | No inferred rule |

*Generic* labels without a returned child use their own threshold. When a
child is returned, a generic parent can be suppressed only without losing its
blocking evidence. If the parent meets its threshold but none of its returned
children resolves to a blocking decision, evaluation returns 503
`ambiguous_moderation_result`. It neither lowers the child's threshold nor
silently approves. This is necessary because children need not exhaust the
broader concepts detected by a parent.

For example, `Products:95` with `Pills:55`, or `Graphic Violence:88` with
`Physical Violence:88`, is unresolved and fails explicitly. A score does not
establish whether the scene is a sporting event or an actual fight. When a
specific child does block, generic ancestors are suppressed as duplicate
blocking evidence. Duplicate instances of one label retain the highest score.

Non-generic parents (Explicit, Explicit Nudity, Hate Symbols, Rude Gestures,
Alcohol Use, Drugs & Tobacco Paraphernalia & Use) retain independent rules.
For example, `Explicit:65` blocks even with `Sex Toys:65`; the child's 70
threshold is not an exemption from the parent's 60 threshold. No category
allow/block decisions or numerical thresholds were changed by these QA fixes.

### Rationale

- **Block at 60:** explicit sexual content, hate symbols, self-harm, weapon
  violence, corpses. These are policy choices, not measured accuracy claims.
  The repository has no real AWS school-photo false-positive/recall benchmark.
- **Allowed:** swimwear, bare backs, shirtless males, partial exposure, and
  kissing. These cover swim meets, track, beach trips, prom, and family photos.
  They still appear in `predictions` with `"blocking": false`.
- **High bars:** sports and school activities produce look-alike signals.
  Physical Violence (contact sports) and Explosions and Blasts (fireworks,
  bonfires) are set to 90. Pills is set to 90 (vitamins, the nurse's office).
  Weapons is set to 85 (fencing, theater props, and culinary knives can still trigger it).
- **Alcohol, drugs, tobacco, gambling:** blocked for a school audience.
  Beverages are set to 85 because sparkling cider and soda look similar.
- **Unknown labels** from a future AWS model return an explicit 503 failure,
  regardless of confidence or a known parent. No automatic rule inheritance.

Known trade-offs to verify with real school photos before launch: Weapons at 85
may reject fencing, archery, ROTC, or theater props. Alcoholic Beverages may
reject adult graduation dinners. Physical Violence at 90 may still flag
wrestling or martial arts. History/art material, skeleton displays, stage makeup,
and ordinary medication also need acceptance coverage. No contextual exemptions
or threshold changes were introduced. Hate-symbol detection is not comprehensive
contextual racism detection.

## Response contract

Success is always HTTP 200 with exactly two top-level keys (Flutter reads only
`offensive`):

```json
{"offensive": true, "predictions": [
  {"class": "Violence", "confidence": 0.9751, "blocking": false},
  {"class": "Weapons", "confidence": 0.9751, "blocking": true}
]}
```

`confidence` keeps the historical 0-1 scale. `class` is the AWS label name.
`blocking` is new and additive. No AWS request IDs, model internals, or error
text are returned.

## Failure behavior (fail-closed)

No failure produces HTTP 200. The Flutter client rejects every non-2xx response.

| Condition | Status | `error` |
| --- | --- | --- |
| AWS region/credentials missing at startup | 503 (and `/health` 503) | `moderation_unavailable` |
| Invalid/expired/unauthorized AWS credentials | 503 | `moderation_provider_auth_failed` |
| AWS throttling | 503 | `moderation_provider_throttled` |
| AWS connect/read timeout | 504 | `moderation_provider_timeout` |
| AWS 5xx / other AWS error | 502 | `moderation_provider_error` |
| AWS unreachable | 502 | `moderation_provider_unavailable` |
| AWS rejects image | 422 | `moderation_image_rejected` |
| Malformed response, unknown label, invalid/missing hierarchy or model version | 503 | `invalid_moderation_result` |
| Blocking generic parent unresolved by returned children | 503 | `ambiguous_moderation_result` |
| Request budget exhausted | 504 | `processing_timeout` |
| Unexpected exception | 503 | `processing_failed` |
| Stuck worker | Gunicorn kills it at about 13 s | (no response; never approves) |

Logs contain fixed codes, the format-validated AWS error code (e.g.
`ThrottlingException`), the AWS model version, the policy version, and label
counts. They never contain AWS messages, request IDs, credentials, signatures,
image bytes, URLs, or user identifiers. botocore/boto3/urllib3 loggers are
silenced below CRITICAL.

## Timing

Nominal network budgets are 5 s Firebase fetch, 2 s AWS connect, and 3 s AWS
read, in addition to decoding/encoding. After encoding, the AWS call starts only
with at least 5.5 s left. The 11 s application budget is checked before and after
moderation. DNS, uploads, and slow trickles are not strictly bounded by the sum
of socket timeouts; Gunicorn kills a stuck worker at about 13 s. Flutter waits
15 s. Queueing and end-to-end latency still need Render acceptance testing.
The botocore client is created once per worker and reused, so its HTTPS
connection can stay warm. No real AWS latency measurement has been made by
these local QA tests.
