# Image-post upload investigation

This is a code-path repair, not confirmation that the released iPhone incident
has been reproduced. No production session logs or device were available.

## Original flow and indefinite waits

1. Create Post used `image_picker` for gallery/camera (1920 px, quality 90).
   Alternatively CameraScreen called `takePicture`, put its temporary `File`
   into UserProvider, and navigated to Create Post. Picker/capture had no
   deadlines, error UI, or lifecycle checks on these paths.
2. Share Post set `uploading = true` and awaited `Database.createPost`.
3. `compressImage`: read the entire file, await `compute` to decode/resize/JPEG
   encode, optionally write a temporary JPEG. All three waits were unbounded.
   Any exception or unsupported decoder silently returned the original file;
   even resizing could be discarded if the resulting JPEG was larger.
4. Storage `putFile`, without explicit metadata, had a three-minute timeout.
   Its timeout handler **awaited `cancel()` without a deadline**.
5. Storage `getDownloadURL()` had **no deadline**.
6. Moderation config RTDB `once()` and HTTP POST were sequential, each capped
   at 15 seconds. Results were ignored; failures were best-effort.
7. Firestore `posts.add(...)` had **no deadline**. A native offline write can
   remain queued, awaiting server acknowledgment. Storage success did not imply
   this step succeeded. Failure left the Storage object behind.
8. Yearbook config RTDB `once()` and HTTP POST were sequential, each capped at
   15 seconds, best-effort. No direct group-document writes occur in this flow.
9. Database caught all errors and returned a bool, losing stage/error details.
   UI reset loading only for false; success navigated without clearing loading.
   Navigation was outside the try block. There was no `finally`.

The proven cause of *unbounded loading* is incomplete deadlines plus incomplete
UI cleanup. The particular unresolved await on the released phone is unknown.
Compression, URL retrieval, Firestore acknowledgment, and cancellation are all
concrete candidates. The comment saying every network stage was bounded was
incorrect. This defect is not inherently iOS-specific.

The installed Storage platform interface 5.1.28 awaits a native startup Future,
then a broadcast stream. Some stream failures/closure and canceled-state paths
do not settle its task completer. Successful completion is normally cached, so
there is no evidence that application code itself missed a success listener:
the old app simply awaited the task and registered no custom listener. New code
handles task completion, terminal snapshots, stream errors/closure, and timeout.

## Current sequence and deadlines

| Stage/log name | Behavior | Deadline |
| --- | --- | --- |
| `picker_gallery` / `picker_camera` | Native picker, same 1920/90 settings | 120 s |
| `camera_capture` | Separate CameraScreen takePicture + guarded handoff | 30 s |
| `selected_file_read` | XFile length then bytes; retain owned bytes for preview/upload | 10 s + 15 s |
| `auth_before_upload` | Current UID and token, not Auth's cached user field | 25 s |
| `group_validation` | Server group read, existence and membership; rules still authoritative | 25 s |
| `image_preprocessing` | Background isolate validates dimensions, decodes, bakes rotation, resizes, encodes | 25 s |
| `auth_upload` | Recheck UID/token after preprocessing | 25 s |
| `storage_upload` / `storage_put_data` | putData with matching JPEG/PNG content type; task plus snapshots | 120 s |
| `download_url` | getDownloadURL | 25 s |
| `moderation` / `moderation_config/http` | Check configured server; it can delete Storage images, so a confirmed non-offensive result is required | 15 s per request; 35 s outer bound |
| `auth_before_write` | Recheck UID/token; backend also checks UID at dispatch | 25 s |
| `firestore_write` | Single preallocated document ID, one set Future; requires acknowledgment | 25 s per wait |
| `storage_cancel`, `storage_delete` | Best-effort cleanup after definite failure/cancellation | 5 s each |
| `storage_listener_cleanup` | Unsubscribe snapshot listener | 2 s |
| `yearbook_config/http` | Existing optional indexing after acknowledged post | 15 s per request; 35 s outer bound |
| `ui` then `navigation` | Always clear loading in finally, then dispatch navigation without awaiting route pop | UI submission safety cap 6 min |

Dependencies remain ordered: the URL requires upload completion; moderation
requires that URL; the post requires a safe moderation outcome. Yearbook indexing
no longer adds up to 30 seconds to foreground loading. There are still no direct
group writes.

A final audit of sibling `moderation_ai/app.py` found another correctness defect:
its `/predict` endpoint can delete `posts/{user_uid}/{image_name}` and return
`offensive: true`. The old app ignored the response despite its comment claiming
the check was disabled. Running that service after publishing would race with
live posts, so it remains before Firestore. A missing/empty moderation endpoint
still means no check is configured. For a configured endpoint, rejection,
malformed responses, HTTP failures, or an unknown result now fail the submission
and clean up its image. Configuration read failures also fail rather than treating
an unknown configuration as disabled. This intentionally closes the existing
false-success/deleted-image gap. The deployed endpoint implementation is unknown;
this is based on the server code in this repository.

Camera setup/switch initialization and orientation have 20/10-second limits;
camera discovery has 20 seconds, disposal five seconds. Video recording is
outside this image-post repair.

Each stage timeout stops advancement to the next stage, even if its underlying
Future completes later. The UI always leaves loading on success, exception,
cancellation or timeout while the Dart event loop is running. This cannot
promise timer execution while iOS suspends/kills the process or a native thread
blocks the entire application. CPU preprocessing runs away from the UI isolate;
a timed-out compute job may finish in the background but cannot initiate upload.

## Retry and cleanup semantics

Firestore timeouts cannot cancel writes. An unknown write outcome is shown as
**not yet confirmed**, never as success. The screen retains the same submission,
locks editing, and Share Post checks that same Future again. It does not create
a second document or re-upload. A late acknowledgment is recognized; a late
rejection schedules bounded Storage deletion. A confirmed failure permits a new
attempt. A navigation error after acknowledgment states that the post was saved
and disables reposting. Concurrent taps share one operation.

Leaving the route cancels pre-write work. A dispatched Firestore write remains
observed because it cannot be canceled. Its photo is retained until its outcome
is known. Cleanup is best-effort: lost permissions, native cancellation failure,
offline deletion, or process termination can still leave a Storage object.
Deleting an image on an *ambiguous* Firestore timeout would risk a broken live
post, so it is deliberately avoided. Pending submission tracking is in memory;
after leaving/restarting, check the feed before creating the same post again.
No persistent cross-session retry queue or server-side orphan janitor was added.

## Image and iOS findings

The unchanged quality target is longest edge 1920 and JPEG quality 85; compact
PNG screenshots can remain lossless when smaller. Dimension limits always
apply, rotation is baked, corrupt/unsupported input is rejected, and source
bytes are limited to 60 MiB / 64 million decoded pixels. Storage gets bytes and
explicit content type, with no temporary compression file to lose or leak.
The selected source file may disappear *after reading* without breaking upload;
a missing file *before reading* produces a reselect message.

The installed image_picker_ios 0.8.12+2 loads library data through PHPicker's
item provider, uses UIImage and the native conversion utilities, and writes a
temporary result. iCloud retrieval/native conversion happens **before** Dart's
picker Future returns. It can therefore stall independently of Storage. Actual
HEIC conversion must be tested on an iPhone. The Dart image codec does not decode
raw HEIC; any unconverted HEIC is now rejected with a JPEG/PNG retry message
instead of silently uploading an unsupported original. Tests exercise rejected
HEIC-like bytes, not a native HEIC conversion fixture. Existing `dart:io` use in
the wider app means this change does not establish web-platform support.

The local ignored `lib/firebase_options.dart` has an old iOS bundle ID
(`com.example.memoriesThroughLenses`) and a different Firebase app ID from
`ios/Runner/GoogleService-Info.plist`. The plist and Xcode target use
`com.derek.memolens`; project and bucket agree between both option sources.
Installed firebase_core 3.4.0 initializes the native default app from the plist
and only soft-checks selected Dart options. This discrepancy is not proof of the
upload failure or proof of which generated file was used for release. No
Firebase configuration, rules, bundle/signing settings, or version was changed.

## Diagnostics and device verification

Temporary JSON console logging is enabled by default. Filter `"flow":"post_upload"`.
Events include operation ID, stage, elapsed milliseconds, start/success/error,
Firebase plugin/error code, progress byte counts, sizes/type, and side-request
HTTP status. Selection has its own ID, linked by the `ui/loading` event's
`selection` field. Capture has a separate `capture-...` ID. No caption, user UID,
image bytes, file path, download URL, token, or response body is logged.

A `start` followed by an `error` with `code: timeout` identifies the bounded
stage. `firestore_write/acknowledged` proves the write Future completed;
`ui/idle` precedes `navigation/start` on success. `storage_progress/success`
without a subsequent `download_url/success` separates upload from URL failure.
Keep diagnostics enabled for a device-validation build, then disable with
`--dart-define=POST_UPLOAD_LOGS=false` before general release (or remove the
PostTrace calls once resolved). Error handling and deadlines do not depend on logs.

Native device discovery failed because Xcode's license has not been accepted.
No license, signing setting or device configuration was changed. iOS-targeted
widget tests use mocked picker channels and a fake backend; they are not native
iPhone/Firebase integration tests.

On a physical iPhone, capture logs separately for camera picker, CameraScreen
handoff, and library. Include HEIC/HEIF, rotated portraits, 48 MP photos, PNG
screenshots, and an iCloud-only photo. Interrupt connectivity at upload, URL
lookup and Firestore acknowledgment; restore it and retry the same submission.
Check one matching Firestore document and Storage object, denied group/session
failures, side-service results, and background/foreground behavior. Actual
Firebase rules, network behavior, native upload callbacks, token refresh and
released-build configuration remain unverified here. The configured moderation
endpoint must also be checked for the expected `{ "offensive": false }` success
contract; availability is now required when an endpoint is configured.

References: [Firestore offline behavior](https://firebase.google.com/docs/firestore/manage-data/enable-offline),
[image_picker platform and temporary-file notes](https://pub.dev/packages/image_picker).

## Validation in this workspace

- `dart format .`: completed; no unrelated source changes retained.
- `flutter analyze`: no errors; 10 existing warnings and 229 infos (239 total),
  down from 248 diagnostics in the original checkout. Exit is nonzero because
  existing diagnostics remain; this is not a clean analyzer pass.
- `flutter test`: 90 tests passed. Coverage includes every staged unresolved
  Future, cancellation/cleanup failure, late Firestore success/rejection,
  duplicate taps, native-task/stream completion races, moderation failure,
  camera/gallery/handoff UI variants, missing/deleted source files, navigation
  failure, large JPEG/PNG, rotation and invalid input.
- No authenticated live Firebase write or native iPhone execution was performed.
