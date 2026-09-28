"""AWS Rekognition DetectModerationLabels provider.

Credentials come only from boto3's standard runtime chain (on Render: the
AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY environment variables). Nothing here
logs or returns AWS exception text, request IDs, headers, or image bytes.
"""

from __future__ import annotations

import json
import os
import re
import time
from io import BytesIO

from botocore.exceptions import (
    BotoCoreError,
    ClientError,
    ConnectTimeoutError,
    NoCredentialsError,
    PartialCredentialsError,
    ReadTimeoutError,
)
from moderation_policy import (
    POLICY_VERSION,
    PROVIDER_MIN_CONFIDENCE,
    MAX_LABELS,
    AmbiguousLabels,
    InvalidLabels,
    Label,
    evaluate,
    taxonomy_level,
    validate_label,
)
from PIL import Image
from service import Failure, Verdict

PROVIDER_NAME = "aws_rekognition"
# Flutter waits ~15s; the app budget is 11s and the image fetch may use 5s.
# One attempt (no retries): 2s connect + 3s read fits inside the remainder.
CONNECT_SECONDS = 2.0
READ_SECONDS = 3.0
# Reserve the nominal connect/read budget plus response-processing headroom.
# DNS, uploads, and slow trickles still require the process watchdog.
MIN_PROVIDER_SECONDS = CONNECT_SECONDS + READ_SECONDS + 0.5
# Rekognition image limits: 5 MB raw bytes, 80px minimum side.
MAX_PAYLOAD_BYTES = 5 * 1024 * 1024
MIN_DIMENSION = 80
# Flutter uploads at most 1920px wide; this only bounds unusual inputs.
MAX_DIMENSION = 4096
# Only if a dense 4096px image cannot fit in 5 MB even at quality 70.
FALLBACK_DIMENSION = 2048
JPEG_QUALITIES = (90, 80, 70)
REGION = re.compile(r"[a-z]{2}(-[a-z]+)+-[0-9]{1,2}\Z")
SAFE_CODE = re.compile(r"[A-Za-z][A-Za-z0-9.]{0,63}\Z")
MODEL_VERSION = re.compile(r"[0-9A-Za-z.\-]{1,32}\Z")
MALFORMED_MARKER = "MemoLensMalformedWireResponse"

AUTH_ERRORS = {
    "AccessDeniedException",
    "AccessDenied",
    "UnrecognizedClientException",
    "InvalidSignatureException",
    "SignatureDoesNotMatch",
    "IncompleteSignature",
    "MissingAuthenticationToken",
    "InvalidClientTokenId",
    "ExpiredToken",
    "ExpiredTokenException",
    "AuthFailure",
}
THROTTLE_ERRORS = {
    "ThrottlingException",
    "Throttling",
    "ProvisionedThroughputExceededException",
    "TooManyRequestsException",
    "RequestLimitExceeded",
    "LimitExceededException",
}
IMAGE_ERRORS = {
    "InvalidImageFormatException",
    "ImageTooLargeException",
    "InvalidParameterException",
}


def aws_region(environ=os.environ) -> str:
    region = environ.get("AWS_REGION") or environ.get("AWS_DEFAULT_REGION")
    if not region or not REGION.fullmatch(region):
        raise RuntimeError("aws_region_missing_or_invalid")
    return region


def flag_malformed_wire_response(response_dict, customized_response_dict, **_):
    # botocore's parser is lenient (e.g. a JSON object where the model expects
    # a list parses as an empty list, i.e. "no labels"). Check the raw shape
    # before parsing so a malformed success body can never become an approval.
    if response_dict.get("status_code") != 200:
        return
    try:
        body = json.loads(response_dict["body"])
        # Validate before botocore can coerce malformed hierarchy field types.
        parse_labels(body)
        valid = True
    except (Failure, KeyError, TypeError, ValueError):
        valid = False
    if not valid:
        # Neutralize the body so the parser cannot crash on it; both the marker
        # and the now-missing ModerationLabels key independently fail closed.
        response_dict["body"] = b"{}"
        customized_response_dict[MALFORMED_MARKER] = True


def build_client(session, *, endpoint_url=None, read_timeout=READ_SECONDS):
    from botocore.config import Config

    client = session.client(
        "rekognition",
        endpoint_url=endpoint_url,
        config=Config(
            connect_timeout=CONNECT_SECONDS,
            read_timeout=read_timeout,
            retries={"total_max_attempts": 1, "mode": "standard"},
            max_pool_connections=1,
        ),
    )
    client.meta.events.register(
        "before-parse.rekognition.DetectModerationLabels",
        flag_malformed_wire_response,
    )
    return client


def create_client(environ=os.environ):
    """Build a Rekognition client locally. Makes no AWS request."""
    import boto3

    session = boto3.session.Session(region_name=aws_region(environ))
    # Resolves from the environment/config only; EC2 metadata lookup is
    # disabled by AWS_EC2_METADATA_DISABLED. Values are never logged.
    if session.get_credentials() is None:
        raise RuntimeError("aws_credentials_missing")
    return build_client(session)


def encode_image(image: Image.Image) -> bytes:
    """Re-encode the validated, EXIF-oriented RGB image as metadata-free JPEG."""
    if min(image.size) < MIN_DIMENSION:
        raise Failure("image_too_small", 422)
    for max_dimension in (MAX_DIMENSION, FALLBACK_DIMENSION):
        working = image
        if max(image.size) > max_dimension:
            working = image.copy()
            working.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
            if min(working.size) < MIN_DIMENSION:
                working.close()
                raise Failure("image_too_small", 422)
        try:
            for quality in JPEG_QUALITIES:
                output = BytesIO()
                # Pillow inherits JPEG comments from image.info unless cleared
                # explicitly. Strip all supported source metadata on every try.
                working.save(
                    output, format="JPEG", quality=quality, comment=b"",
                    exif=b"", icc_profile=None, xmp=None,
                )
                if output.tell() <= MAX_PAYLOAD_BYTES:
                    return output.getvalue()
        finally:
            if working is not image:
                working.close()
    raise Failure("image_too_large", 413)


def parse_labels(response) -> tuple[list[Label], str]:
    try:
        if not isinstance(response, dict) or response.get(MALFORMED_MARKER):
            raise InvalidLabels
        raw_labels = response["ModerationLabels"]
        if not isinstance(raw_labels, list) or len(raw_labels) > MAX_LABELS:
            raise InvalidLabels
        labels = []
        for raw in raw_labels:
            if not isinstance(raw, dict):
                raise InvalidLabels
            label = Label(raw["Name"], raw["Confidence"], raw["ParentName"])
            validate_label(label)
            level = raw["TaxonomyLevel"]
            if type(level) is not int or level != taxonomy_level(label.name):
                raise InvalidLabels
            labels.append(label)
        version = response["ModerationModelVersion"]
        if not isinstance(version, str) or not MODEL_VERSION.fullmatch(version):
            raise InvalidLabels
        return labels, version
    except (InvalidLabels, KeyError, TypeError):
        raise Failure("invalid_moderation_result", 503) from None


def safe_error_code(error: ClientError) -> str:
    try:
        code = error.response["Error"]["Code"]
    except (KeyError, TypeError, AttributeError):
        return "unrecognized"
    return (
        code if isinstance(code, str) and SAFE_CODE.fullmatch(code) else "unrecognized"
    )


def provider_failure(error: Exception) -> Failure:
    if isinstance(error, (ConnectTimeoutError, ReadTimeoutError)):
        return Failure("moderation_provider_timeout", 504)
    if isinstance(error, (NoCredentialsError, PartialCredentialsError)):
        return Failure("moderation_provider_auth_failed", 503)
    if isinstance(error, ClientError):
        code = safe_error_code(error)
        if code in AUTH_ERRORS:
            return Failure("moderation_provider_auth_failed", 503, provider_error=code)
        if code in THROTTLE_ERRORS:
            return Failure("moderation_provider_throttled", 503, provider_error=code)
        if code in IMAGE_ERRORS:
            return Failure("moderation_image_rejected", 422, provider_error=code)
        return Failure("moderation_provider_error", 502, provider_error=code)
    return Failure("moderation_provider_unavailable", 502)


class RekognitionProvider:
    def __init__(self, client):
        self._client = client

    def moderate(self, image: Image.Image, deadline: float) -> Verdict:
        payload = encode_image(image)
        if deadline - time.monotonic() < MIN_PROVIDER_SECONDS:
            raise Failure("processing_timeout", 504)
        try:
            response = self._client.detect_moderation_labels(
                Image={"Bytes": payload}, MinConfidence=PROVIDER_MIN_CONFIDENCE
            )
        except (BotoCoreError, ClientError) as error:
            raise provider_failure(error) from None
        labels, model_version = parse_labels(response)
        try:
            evaluation = evaluate(labels)
        except AmbiguousLabels:
            raise Failure("ambiguous_moderation_result", 503) from None
        except InvalidLabels:
            raise Failure("invalid_moderation_result", 503) from None
        return Verdict(
            evaluation.offensive,
            evaluation.predictions,
            {
                "provider": PROVIDER_NAME,
                "provider_model_version": model_version,
                "policy_version": POLICY_VERSION,
                "label_count": len(labels),
                "blocking_label_count": evaluation.blocking_count,
            },
        )


def load_provider(environ=os.environ) -> RekognitionProvider:
    return RekognitionProvider(create_client(environ))
