"""AWS Rekognition provider tests. Never contacts AWS.

A loopback HTTP server impersonates the Rekognition JSON endpoint so the real
boto3 client (signing, retry configuration, timeouts, error parsing) is
exercised without credentials or Internet access.
"""

import base64
import json
import logging
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from unittest.mock import Mock

import boto3
import pytest
import rekognition_provider
import service
from botocore.exceptions import (
    ConnectTimeoutError,
    EndpointConnectionError,
    NoCredentialsError,
    ReadTimeoutError,
)
from PIL import Image
from rekognition_provider import RekognitionProvider, encode_image
from service import Failure, create_app
from test_service import payload, photo

FAKE_KEY_ID = "test-access-key-id-not-real"
FAKE_SECRET = "fake-secret-access-key-for-tests-only"


class FakeRekognition:
    def __init__(self):
        self.requests = []
        self.replies = []
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), self.handler())
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def handler(self):
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                fake.requests.append(
                    {"target": self.headers["X-Amz-Target"], "body": json.loads(body)}
                )
                status, reply, delay = fake.replies.pop(0)
                time.sleep(delay)
                data = reply if isinstance(reply, bytes) else json.dumps(reply).encode()
                try:
                    self.send_response(status)
                    self.send_header("Content-Type", "application/x-amz-json-1.1")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    pass

        return Handler

    def reply(self, status=200, body=None, delay=0.0):
        self.replies.append((status, {} if body is None else body, delay))

    @property
    def url(self):
        return f"http://127.0.0.1:{self.server.server_address[1]}"


@pytest.fixture
def aws():
    fake = FakeRekognition()
    fake.thread.start()
    yield fake
    fake.server.shutdown()
    fake.server.server_close()


def client_for(aws, read_timeout=rekognition_provider.READ_SECONDS):
    # The production client builder (timeouts, no retries, raw-shape check),
    # pointed at the loopback fake instead of AWS.
    session = boto3.session.Session(
        aws_access_key_id=FAKE_KEY_ID,
        aws_secret_access_key=FAKE_SECRET,
        region_name="us-west-2",
    )
    return rekognition_provider.build_client(
        session, endpoint_url=aws.url, read_timeout=read_timeout
    )


def labels_response(*labels, version="7.0"):
    return {
        "ModerationLabels": [
            {
                "Name": name,
                "Confidence": confidence,
                "ParentName": parent,
                "TaxonomyLevel": level,
            }
            for name, confidence, parent, level in labels
        ],
        "ModerationModelVersion": version,
        "ContentTypes": [],
    }


def predict(provider, image=None):
    data = image or photo(size=(640, 480))
    app = create_app(provider=provider, fetcher=lambda *_: data)
    return app.test_client().post("/predict", json=payload())


def test_benign_school_photo_end_to_end(aws):
    aws.reply(body=labels_response())
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 200
    assert response.json == {"offensive": False, "predictions": []}
    assert len(aws.requests) == 1
    request = aws.requests[0]
    assert request["target"] == "RekognitionService.DetectModerationLabels"
    assert request["body"]["MinConfidence"] == 50.0
    assert set(request["body"]) == {"Image", "MinConfidence"}
    sent = base64.b64decode(request["body"]["Image"]["Bytes"])
    with Image.open(BytesIO(sent)) as image:
        assert image.format == "JPEG"
        assert image.size == (640, 480)


def test_allowed_labels_from_aws_stay_benign(aws):
    aws.reply(
        body=labels_response(
            ("Swimwear or Underwear", 98.2, "", 1),
            ("Male Swimwear or Underwear", 98.2, "Swimwear or Underwear", 2),
        )
    )
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 200
    assert response.json["offensive"] is False
    assert [p["blocking"] for p in response.json["predictions"]] == [False, False]


def test_unsafe_labels_from_aws_are_offensive(aws):
    aws.reply(
        body=labels_response(
            ("Violence", 97.51234, "", 1),
            ("Weapons", 97.51234, "Violence", 2),
        )
    )
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 200
    assert response.json == {
        "offensive": True,
        "predictions": [
            {"class": "Violence", "confidence": 0.9751, "blocking": False},
            {"class": "Weapons", "confidence": 0.9751, "blocking": True},
        ],
    }


def test_multiple_moderation_labels_across_categories(aws):
    aws.reply(
        body=labels_response(
            ("Drugs & Tobacco", 91.0, "", 1),
            ("Drugs & Tobacco Paraphernalia & Use", 91.0, "Drugs & Tobacco", 2),
            ("Smoking", 91.0, "Drugs & Tobacco Paraphernalia & Use", 3),
            (
                "Kissing on the Lips",
                64.0,
                "Non-Explicit Nudity of Intimate parts and Kissing",
                2,
            ),
            ("Non-Explicit Nudity of Intimate parts and Kissing", 64.0, "", 1),
        )
    )
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 200
    assert response.json["offensive"] is True
    blocking = {p["class"] for p in response.json["predictions"] if p["blocking"]}
    assert blocking == {"Drugs & Tobacco Paraphernalia & Use", "Smoking"}
    assert len(response.json["predictions"]) == 5


@pytest.mark.parametrize(
    "body",
    [
        {},
        {"ModerationLabels": None},
        {"ModerationLabels": "Weapons"},
        {"ModerationLabels": [{"Name": "Weapons"}]},
        {"ModerationLabels": [{"Confidence": 99.0}]},
        {"ModerationLabels": [{"Name": "Weapons", "Confidence": "high"}]},
        {"ModerationLabels": [{"Name": "Weapons", "Confidence": 250.0}]},
        {"ModerationLabels": [{"Name": "Weapons", "Confidence": -3}]},
        {"ModerationLabels": [{"Name": "", "Confidence": 99.0}]},
        {
            "ModerationLabels": [
                {"Name": "Weapons", "Confidence": 99.0, "TaxonomyLevel": 9}
            ]
        },
        {"ModerationLabels": [None]},
    ],
)
def test_malformed_aws_response_fails_closed(body):
    client = Mock()
    client.detect_moderation_labels.return_value = body
    response = predict(RekognitionProvider(client))
    assert response.status_code == 503
    assert response.json["error"] == "invalid_moderation_result"
    assert "offensive" not in response.json


@pytest.mark.parametrize(
    "reply,status,code",
    [
        (b"not json", 503, "invalid_moderation_result"),
        (b"{}", 503, "invalid_moderation_result"),
        (b"[]", 503, "invalid_moderation_result"),
        (b'{"ModerationLabels": null}', 503, "invalid_moderation_result"),
        # botocore alone would parse these as "no labels" (an approval).
        (b'{"ModerationLabels": {}}', 503, "invalid_moderation_result"),
        (
            b'{"ModerationLabels": {"Name": "Weapons"}}',
            503,
            "invalid_moderation_result",
        ),
        (b'{"ModerationLabels": [1]}', 503, "invalid_moderation_result"),
        (
            b'{"ModerationLabels": [{"Name": "Weapons", "Confidence": "99"}]}',
            503,
            "invalid_moderation_result",
        ),
        (
            b'{"ModerationLabels": [{"Name": "Weapons", "Confidence": true}]}',
            503,
            "invalid_moderation_result",
        ),
        (
            b'{"ModerationLabels": [{"Confidence": 99.0}]}',
            503,
            "invalid_moderation_result",
        ),
    ],
)
def test_malformed_aws_wire_response_fails_closed(aws, reply, status, code):
    aws.reply(body=reply)
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == status
    assert response.json["error"] == code
    assert "offensive" not in response.json


def test_well_formed_empty_wire_response_is_benign(aws):
    aws.reply(body=b'{"ModerationLabels": [], "ModerationModelVersion": "7.0"}')
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 200
    assert response.json == {"offensive": False, "predictions": []}


@pytest.mark.parametrize(
    "status,aws_code",
    [
        (400, "UnrecognizedClientException"),
        (400, "InvalidSignatureException"),
        (400, "AccessDeniedException"),
        (403, "AccessDeniedException"),
        (400, "ExpiredTokenException"),
    ],
)
def test_aws_authentication_failure_fails_closed(aws, status, aws_code):
    aws.reply(status, {"__type": aws_code, "message": FAKE_SECRET})
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 503
    assert response.json["error"] == "moderation_provider_auth_failed"
    assert "offensive" not in response.json
    assert FAKE_SECRET.encode() not in response.data


def test_missing_credentials_at_call_time_fails_closed():
    client = Mock()
    client.detect_moderation_labels.side_effect = NoCredentialsError()
    response = predict(RekognitionProvider(client))
    assert response.status_code == 503
    assert response.json["error"] == "moderation_provider_auth_failed"


@pytest.mark.parametrize(
    "status,aws_code",
    [
        (400, "ThrottlingException"),
        (500, "ThrottlingException"),
        (400, "ProvisionedThroughputExceededException"),
    ],
)
def test_aws_throttling_fails_closed_without_retry(aws, status, aws_code):
    aws.reply(status, {"__type": aws_code})
    aws.reply(body=labels_response())  # would approve if a retry happened
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 503
    assert response.json["error"] == "moderation_provider_throttled"
    assert "offensive" not in response.json
    assert len(aws.requests) == 1


@pytest.mark.parametrize(
    "status,aws_code", [(500, "InternalServerError"), (503, "ServiceUnavailable")]
)
def test_aws_service_error_fails_closed_without_retry(aws, status, aws_code):
    aws.reply(status, {"__type": aws_code})
    aws.reply(body=labels_response())
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 502
    assert response.json["error"] == "moderation_provider_error"
    assert "offensive" not in response.json
    assert len(aws.requests) == 1


@pytest.mark.parametrize(
    "aws_code", ["InvalidImageFormatException", "ImageTooLargeException"]
)
def test_aws_image_rejection_fails_closed(aws, aws_code):
    aws.reply(400, {"__type": aws_code})
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 422
    assert response.json["error"] == "moderation_image_rejected"


def test_aws_read_timeout_fails_closed_without_retry(aws):
    aws.reply(body=labels_response(), delay=1.0)
    aws.reply(body=labels_response())
    started = time.monotonic()
    response = predict(RekognitionProvider(client_for(aws, read_timeout=0.3)))
    assert response.status_code == 504
    assert response.json["error"] == "moderation_provider_timeout"
    assert "offensive" not in response.json
    assert time.monotonic() - started < 1.0
    assert len(aws.requests) == 1


@pytest.mark.parametrize(
    "error",
    [
        ConnectTimeoutError(endpoint_url="https://rekognition.us-west-2.amazonaws.com"),
        ReadTimeoutError(endpoint_url="https://rekognition.us-west-2.amazonaws.com"),
    ],
)
def test_aws_timeout_exceptions_map_to_504(error):
    client = Mock()
    client.detect_moderation_labels.side_effect = error
    response = predict(RekognitionProvider(client))
    assert response.status_code == 504
    assert response.json["error"] == "moderation_provider_timeout"


def test_aws_unreachable_fails_closed():
    client = Mock()
    client.detect_moderation_labels.side_effect = EndpointConnectionError(
        endpoint_url="https://rekognition.us-west-2.amazonaws.com"
    )
    response = predict(RekognitionProvider(client))
    assert response.status_code == 502
    assert response.json["error"] == "moderation_provider_unavailable"


def test_unexpected_client_exception_fails_closed():
    client = Mock()
    client.detect_moderation_labels.side_effect = RuntimeError(FAKE_SECRET)
    response = predict(RekognitionProvider(client))
    assert response.status_code == 503
    assert FAKE_SECRET.encode() not in response.data


@pytest.mark.parametrize("remaining", [0.5, 1.1, 4.9, 5.1])
def test_provider_skips_call_without_full_nominal_budget(remaining):
    client = Mock()
    with Image.new("RGB", (200, 200)) as image, pytest.raises(Failure) as caught:
        RekognitionProvider(client).moderate(image, time.monotonic() + remaining)
    assert caught.value.code == "processing_timeout"
    client.detect_moderation_labels.assert_not_called()


def test_provider_logs_are_redacted(aws):
    messages = []

    class Capture(logging.Handler):
        def emit(self, record):
            messages.append(record.getMessage())

    handler = Capture()
    service.logger.addHandler(handler)
    root = logging.getLogger()
    root.addHandler(handler)
    previous = root.level
    root.setLevel(logging.DEBUG)
    try:
        aws.reply(400, {"__type": "ThrottlingException", "message": FAKE_SECRET})
        predict(RekognitionProvider(client_for(aws)))
        aws.reply(body=labels_response(("Weapons", 99.0, "Violence", 2)))
        predict(RekognitionProvider(client_for(aws)))
    finally:
        service.logger.removeHandler(handler)
        root.removeHandler(handler)
        root.setLevel(previous)
    serialized = "\n".join(messages)
    for secret in (FAKE_SECRET, FAKE_KEY_ID, "private-download-token", "Signature="):
        assert secret not in serialized
    events = [json.loads(m) for m in messages if m.startswith("{")]
    assert {
        "stage": "moderation",
        "event": "failure",
        "code": "moderation_provider_throttled",
        "status": 503,
        "provider_error": "ThrottlingException",
    }.items() <= next(e for e in events if e["event"] == "failure").items()
    success = next(
        e for e in events if e["stage"] == "moderation" and e["event"] == "success"
    )
    assert success["provider"] == "aws_rekognition"
    assert success["provider_model_version"] == "7.0"
    assert success["policy_version"] == "memolens-school-v1"
    assert success["blocking_label_count"] == 1


def test_unsafe_provider_error_code_is_not_logged_verbatim():
    error = Mock(response={"Error": {"Code": "Bad\ncode with spaces"}})
    assert rekognition_provider.safe_error_code(error) == "unrecognized"


# --- image payload preparation -------------------------------------------


def encoded(image):
    with Image.open(BytesIO(encode_image(image))) as result:
        result.load()
        return result.format, result.size, result.getexif()


def test_payload_is_metadata_free_jpeg_with_native_dimensions():
    source = Image.new("RGB", (1170, 646), "red")
    exif = Image.Exif()
    exif[0x010F] = "PrivateCameraMaker"
    buffer = BytesIO()
    source.save(buffer, format="JPEG", exif=exif)
    with service.decode_image(buffer.getvalue()) as decoded:
        fmt, size, metadata = encoded(decoded)
    assert (fmt, size) == ("JPEG", (1170, 646))
    assert dict(metadata) == {}


def test_oversized_dimensions_are_downscaled_preserving_aspect_ratio():
    with Image.new("RGB", (8000, 2000), "green") as image:
        fmt, size, _ = encoded(image)
    assert fmt == "JPEG"
    assert size == (4096, 1024)


@pytest.mark.parametrize("size", [(79, 500), (500, 79), (1, 1), (16000, 200)])
def test_images_too_small_for_rekognition_fail_explicitly(size):
    with Image.new("RGB", size) as image, pytest.raises(Failure) as caught:
        encode_image(image)
    assert (caught.value.code, caught.value.status) == ("image_too_small", 422)


def test_payload_over_aws_byte_limit_fails_explicitly(monkeypatch):
    monkeypatch.setattr(rekognition_provider, "MAX_PAYLOAD_BYTES", 100)
    with Image.effect_noise((300, 300), 100) as noise, noise.convert("RGB") as image:
        with pytest.raises(Failure) as caught:
            encode_image(image)
    assert (caught.value.code, caught.value.status) == ("image_too_large", 413)


def test_payload_quality_steps_down_before_failing(monkeypatch):
    with Image.effect_noise((600, 600), 100) as noise, noise.convert("RGB") as image:
        sizes = {}
        for quality in rekognition_provider.JPEG_QUALITIES:
            buffer = BytesIO()
            image.save(buffer, format="JPEG", quality=quality)
            sizes[quality] = buffer.tell()
        monkeypatch.setattr(rekognition_provider, "MAX_PAYLOAD_BYTES", sizes[70])
        payload_bytes = encode_image(image)
    assert len(payload_bytes) == sizes[70]


def test_small_benign_image_rejected_before_aws_call(aws):
    response = predict(RekognitionProvider(client_for(aws)), image=photo(size=(64, 48)))
    assert response.status_code == 422
    assert response.json["error"] == "image_too_small"
    assert aws.requests == []


def test_hermetic_guard_blocks_real_aws_connections():
    import socket

    with pytest.raises(AssertionError, match="non-loopback"):
        socket.create_connection(("52.119.160.1", 443), timeout=0.1)


def test_dense_image_falls_back_to_smaller_dimension_before_failing(monkeypatch):
    monkeypatch.setattr(rekognition_provider, "MAX_DIMENSION", 400)
    monkeypatch.setattr(rekognition_provider, "FALLBACK_DIMENSION", 200)
    with Image.effect_noise((400, 400), 100) as noise, noise.convert("RGB") as image:
        smallest_full_size = BytesIO()
        image.save(smallest_full_size, format="JPEG", quality=70)
        monkeypatch.setattr(
            rekognition_provider, "MAX_PAYLOAD_BYTES", smallest_full_size.tell() - 1
        )
        fmt, size, _ = encoded(image)
    assert (fmt, size) == ("JPEG", (200, 200))


@pytest.mark.parametrize(
    "field,value",
    [
        ("ParentName", False),
        ("ParentName", None),
        ("ParentName", 0),
        ("ParentName", []),
        ("ParentName", {}),
        ("ParentName", "Violence"),
        ("TaxonomyLevel", True),
        ("TaxonomyLevel", None),
        ("TaxonomyLevel", 3.0),
        ("TaxonomyLevel", "3"),
        ("TaxonomyLevel", 1),
    ],
)
def test_malformed_hierarchy_rejected_before_sdk_coercion(aws, field, value):
    body = labels_response(("Bare Back", 99, "Non-Explicit Nudity", 3))
    body["ModerationLabels"][0][field] = value
    aws.reply(body=body)
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 503
    assert response.json["error"] == "invalid_moderation_result"
    assert "offensive" not in response.json


@pytest.mark.parametrize("field", ["ParentName", "TaxonomyLevel"])
def test_missing_hierarchy_field_cannot_approve(aws, field):
    body = labels_response(("Bare Back", 99, "Non-Explicit Nudity", 3))
    del body["ModerationLabels"][0][field]
    aws.reply(body=body)
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 503
    assert "offensive" not in response.json


@pytest.mark.parametrize("version", [None, "", False, 7.0])
def test_invalid_model_version_cannot_make_empty_labels_an_approval(aws, version):
    aws.reply(body=labels_response(version=version))
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 503
    assert "offensive" not in response.json


def test_missing_model_version_cannot_make_empty_labels_an_approval(aws):
    aws.reply(body={"ModerationLabels": []})
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 503
    assert "offensive" not in response.json


@pytest.mark.parametrize(
    "labels,error",
    [
        (
            [("Unreviewed Category", 79, "", 1)],
            "invalid_moderation_result",
        ),
        (
            [("Unreviewed Child", 99, "Non-Explicit Nudity", 3)],
            "invalid_moderation_result",
        ),
        (
            [("Violence", 99, "", 1), ("Bare Back", 99, "Violence", 3)],
            "invalid_moderation_result",
        ),
        (
            [
                ("Drugs & Tobacco", 95, "", 1),
                ("Products", 95, "Drugs & Tobacco", 2),
                ("Pills", 55, "Products", 3),
            ],
            "ambiguous_moderation_result",
        ),
        (
            [
                ("Violence", 88, "", 1),
                ("Graphic Violence", 88, "Violence", 2),
                ("Physical Violence", 88, "Graphic Violence", 3),
            ],
            "ambiguous_moderation_result",
        ),
    ],
)
def test_reproduced_approval_defects_fail_closed_through_real_sdk(aws, labels, error):
    aws.reply(body=labels_response(*labels))
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 503
    assert response.json["error"] == error
    assert "offensive" not in response.json
    assert len(aws.requests) == 1


@pytest.mark.parametrize("downscale", [False, True])
def test_private_metadata_removed_from_actual_aws_payload(aws, monkeypatch, downscale):
    if downscale:
        monkeypatch.setattr(rekognition_provider, "MAX_DIMENSION", 200)
    source = BytesIO()
    exif = Image.Exif()
    exif[0x010F] = "SyntheticPrivateCamera"
    exif[0x8825] = {1: "N", 2: (1.0, 2.0, 3.0)}
    markers = [
        b"SyntheticPrivateComment",
        b"SyntheticPrivateCamera",
        b"SyntheticPrivateProfile",
        b"SyntheticPrivateXMP",
    ]
    with Image.new("RGB", (400, 300), "blue") as image:
        image.save(
            source, format="JPEG", comment=markers[0], exif=exif,
            icc_profile=markers[2], xmp=markers[3],
        )
    aws.reply(body=labels_response())
    response = predict(RekognitionProvider(client_for(aws)), image=source.getvalue())
    assert response.status_code == 200
    sent = base64.b64decode(aws.requests[0]["body"]["Image"]["Bytes"])
    assert all(marker not in sent for marker in markers)
    with Image.open(BytesIO(sent)) as image:
        assert not image.getexif()
        metadata_keys = ("comment", "exif", "icc_profile", "xmp")
        assert not any(image.info.get(k) for k in metadata_keys)
        assert image.size == ((200, 150) if downscale else (400, 300))


def test_provider_checks_budget_after_encoding(monkeypatch):
    now = [0.0]
    monkeypatch.setattr(rekognition_provider.time, "monotonic", lambda: now[0])

    def slow_encoding(image):
        now[0] = 6.0
        return b"synthetic-image-bytes"

    monkeypatch.setattr(rekognition_provider, "encode_image", slow_encoding)
    client = Mock()
    with Image.new("RGB", (100, 100)) as image, pytest.raises(Failure) as caught:
        RekognitionProvider(client).moderate(image, 11.0)
    assert caught.value.code == "processing_timeout"
    client.detect_moderation_labels.assert_not_called()


def test_blocking_grandchild_remains_offensive_through_generic_ancestors(aws):
    aws.reply(
        body=labels_response(
            ("Violence", 96, "", 1),
            ("Graphic Violence", 96, "Violence", 2),
            ("Physical Violence", 96, "Graphic Violence", 3),
        )
    )
    response = predict(RekognitionProvider(client_for(aws)))
    assert response.status_code == 200
    assert response.json["offensive"] is True
    assert [p["class"] for p in response.json["predictions"] if p["blocking"]] == [
        "Physical Violence"
    ]
