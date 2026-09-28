"""Bounded, read-only photo moderation. Never log request values or exceptions.

This module is provider-agnostic: it validates, fetches, and decodes the image,
then asks the configured ModerationProvider for a verdict.
"""

from __future__ import annotations

import ipaddress
import json
import logging
import re
import socket
import time
import uuid
import warnings
import dataclasses
from dataclasses import dataclass
from io import BytesIO
from typing import Protocol
from urllib.parse import parse_qs, quote, unquote, urlencode, urlsplit

import certifi
import urllib3
from flask import Flask, g, jsonify, request
from PIL import Image, ImageOps, UnidentifiedImageError
from werkzeug.exceptions import HTTPException

STORAGE_HOST = "firebasestorage.googleapis.com"
STORAGE_BUCKET = "memories-through-lenses.appspot.com"
MAX_IMAGE_BYTES = 12 * 1024 * 1024
MAX_IMAGE_PIXELS = 16_000_000
REQUEST_SECONDS = 11.0
FETCH_SECONDS = 5.0
USER_UID = re.compile(r"[A-Za-z0-9_-]{1,128}\Z")
INVALID_ESCAPE = re.compile(r"%(?![0-9A-Fa-f]{2})")
MAX_FILENAME_BYTES = 255
TOKEN = re.compile(r"[A-Za-z0-9_-]{1,1024}\Z")
RESERVED_LOG_FIELDS = {"stage", "event", "request_id", "code", "status", "offensive"}
logger = logging.getLogger("memolens.moderation")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
logger.setLevel(logging.INFO)
logger.propagate = False
# urllib3 DEBUG messages can include signed query strings, and botocore DEBUG
# messages include request signatures and image payloads. Our logs report codes.
for _noisy in ("urllib3", "botocore", "boto3"):
    logging.getLogger(_noisy).setLevel(logging.CRITICAL)


class Failure(Exception):
    def __init__(self, code: str, status: int, **log_fields):
        self.code = code
        self.status = status
        # Locally generated or allowlisted values only; logged, never returned.
        self.log_fields = log_fields
        super().__init__(code)


@dataclass(frozen=True)
class Verdict:
    offensive: bool
    predictions: list[dict]
    # Safe diagnostic values (versions, counts) for logs, never the response.
    log_fields: dict = dataclasses.field(default_factory=dict)


class ModerationProvider(Protocol):
    def moderate(self, image: Image.Image, deadline: float) -> Verdict:
        """Return a verdict or raise Failure; never approve on error."""


def event(stage: str, outcome: str, **fields):
    # Values supplied here are generated locally, never copied from the request.
    logger.info(json.dumps({"stage": stage, "event": outcome, **fields}))


def valid_image_name(name: str) -> bool:
    # A single literal object-name component, never a filesystem path. Permit
    # historical timestamps and ordinary Unicode filenames, but no alternate
    # separators, controls, dot segments, or nested percent-encoding semantics.
    return (
        bool(name)
        and name.isprintable()
        and name == name.strip()
        and name not in {".", ".."}
        and not any(character in name for character in ("/", "\\", "%"))
        and len(name.encode("utf-8")) <= MAX_FILENAME_BYTES
    )


def validate_input(data) -> str:
    if not isinstance(data, dict):
        raise Failure("invalid_request", 400)
    for field in ("url", "user_uid", "image_name"):
        if not isinstance(data.get(field), str) or not data[field]:
            raise Failure("missing_or_invalid_fields", 400)
    uid, name, url = data["user_uid"], data["image_name"], data["url"]
    if not USER_UID.fullmatch(uid) or not valid_image_name(name):
        raise Failure("invalid_object_identity", 400)
    if (
        len(url) > 4096
        or not url.isascii()
        or any(ord(c) <= 32 or ord(c) == 127 for c in url)
    ):
        raise Failure("invalid_image_url", 400)
    try:
        parsed = urlsplit(url)
        if (
            parsed.scheme != "https"
            or parsed.hostname != STORAGE_HOST
            or parsed.netloc not in (STORAGE_HOST, STORAGE_HOST + ":443")
            or parsed.username
            or parsed.password
            or parsed.fragment
        ):
            raise Failure("disallowed_image_url", 400)
        prefix = f"/v0/b/{STORAGE_BUCKET}/o/"
        if not parsed.path.startswith(prefix):
            raise Failure("disallowed_storage_object", 400)
        encoded_object = parsed.path[len(prefix) :]
        # Firebase's object occupies one URL path segment. Decode exactly once;
        # unquote alone would silently preserve malformed percent escapes.
        if "/" in encoded_object or INVALID_ESCAPE.search(encoded_object):
            raise Failure("invalid_object_path", 400)
        decoded_object = unquote(encoded_object, encoding="utf-8", errors="strict")
        components = decoded_object.split("/")
        if (
            len(components) != 3
            or components[0] != "posts"
            or not USER_UID.fullmatch(components[1])
            or not valid_image_name(components[2])
        ):
            raise Failure("invalid_object_path", 400)
        if components != ["posts", uid, name]:
            raise Failure("object_identity_mismatch", 400)
        query = parse_qs(parsed.query, strict_parsing=True, keep_blank_values=True)
        if (
            set(query) != {"alt", "token"}
            or query["alt"] != ["media"]
            or len(query["token"]) != 1
            or not TOKEN.fullmatch(query["token"][0])
        ):
            raise Failure("invalid_download_parameters", 400)
    except (ValueError, UnicodeError):
        raise Failure("invalid_image_url", 400) from None
    # Build a canonical target rather than forwarding unchecked URL syntax.
    return (
        prefix
        + quote(decoded_object, safe="")
        + "?"
        + urlencode({"alt": "media", "token": query["token"][0]})
    )


def public_storage_address() -> str:
    addresses = socket.getaddrinfo(STORAGE_HOST, 443, type=socket.SOCK_STREAM)
    if not addresses:
        raise Failure("image_host_unavailable", 502)
    ips = {entry[4][0] for entry in addresses}
    # Pin the checked address to the TLS connection; there is no second DNS lookup.
    if any(
        not ipaddress.ip_address(ip).is_global or ipaddress.ip_address(ip).is_multicast
        for ip in ips
    ):
        raise Failure("unsafe_image_address", 502)
    return sorted(ips, key=lambda ip: (":" in ip, ip))[0]


def fetch_image(target: str, deadline: float) -> bytes:
    end = min(deadline, time.monotonic() + FETCH_SECONDS)
    pool = None
    response = None
    try:
        address = public_storage_address()
        remaining = end - time.monotonic()
        if remaining <= 0:
            raise Failure("image_fetch_timeout", 504)
        pool = urllib3.HTTPSConnectionPool(
            address,
            port=443,
            server_hostname=STORAGE_HOST,
            assert_hostname=STORAGE_HOST,
            cert_reqs="CERT_REQUIRED",
            ca_certs=certifi.where(),
            maxsize=1,
        )
        response = pool.urlopen(
            "GET",
            target,
            headers={"Host": STORAGE_HOST, "Accept-Encoding": "identity"},
            timeout=urllib3.Timeout(
                connect=min(2.0, remaining), read=min(2.0, remaining)
            ),
            retries=False,
            redirect=False,
            preload_content=False,
        )
        if response.status != 200:
            raise Failure("image_fetch_failed", 502)
        if response.headers.get("Content-Encoding", "identity").lower() != "identity":
            raise Failure("unsupported_image_encoding", 422)
        if response.headers.get("Content-Type", "").split(";")[0].lower() not in {
            "image/jpeg",
            "image/png",
        }:
            raise Failure("unsupported_image_type", 422)
        length = response.headers.get("Content-Length")
        if length is not None and (
            not length.isdigit() or int(length) > MAX_IMAGE_BYTES
        ):
            raise Failure("image_too_large", 413)
        output = bytearray()
        # read1 returns available data; a slow trickle cannot reset the wall budget.
        while True:
            if time.monotonic() >= end:
                raise Failure("image_fetch_timeout", 504)
            chunk = response.read1(64 * 1024, decode_content=False)
            if time.monotonic() >= end:
                raise Failure("image_fetch_timeout", 504)
            if not chunk:
                break
            output.extend(chunk)
            if len(output) > MAX_IMAGE_BYTES:
                raise Failure("image_too_large", 413)
        if not output:
            raise Failure("invalid_image", 422)
        return bytes(output)
    except urllib3.exceptions.TimeoutError:
        raise Failure("image_fetch_timeout", 504) from None
    except (urllib3.exceptions.HTTPError, OSError, ValueError):
        raise Failure("image_fetch_failed", 502) from None
    finally:
        if response is not None:
            response.close()
        if pool is not None:
            pool.close()


def decode_image(data: bytes) -> Image.Image:
    if not data or len(data) > MAX_IMAGE_BYTES:
        raise Failure("invalid_image", 422)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(data)) as image:
                if image.format not in {"JPEG", "PNG"}:
                    raise Failure("unsupported_image_type", 422)
                if image.width * image.height > MAX_IMAGE_PIXELS:
                    raise Failure("image_too_large", 413)
                image.load()
                # Preserve detail/aspect ratio; providers do their own sizing.
                # Squashing to 64x64 caused reproducible false positives.
                with ImageOps.exif_transpose(image) as oriented:
                    return oriented.convert("RGB")
    except (
        UnidentifiedImageError,
        OSError,
        ValueError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ):
        raise Failure("invalid_image", 422) from None


def validate_verdict(verdict) -> tuple[bool, list[dict]]:
    # Defense in depth: only an exact boolean verdict with well-formed
    # predictions can reach Flutter. Anything else fails closed.
    try:
        if (
            not isinstance(verdict, Verdict)
            or not isinstance(verdict.offensive, bool)
            or not isinstance(verdict.predictions, list)
            or not isinstance(verdict.log_fields, dict)
            or not RESERVED_LOG_FIELDS.isdisjoint(verdict.log_fields)
        ):
            raise ValueError
        predictions = []
        for item in verdict.predictions:
            confidence = item["confidence"]
            if (
                not isinstance(item["class"], str)
                or isinstance(confidence, bool)
                or not isinstance(confidence, (int, float))
                or not 0 <= confidence <= 1
            ):
                raise ValueError
            predictions.append(dict(item))
        return verdict.offensive, predictions
    except (TypeError, ValueError, KeyError, AttributeError):
        raise Failure("invalid_moderation_result", 503) from None


def create_app(*, provider=None, fetcher=fetch_image, startup_ready=True) -> Flask:
    app = Flask(__name__)
    app.config.update(
        MAX_CONTENT_LENGTH=8192, PROVIDER=provider, STARTUP_READY=startup_ready
    )

    @app.before_request
    def received():
        g.request_id = uuid.uuid4().hex
        g.started = time.monotonic()
        g.stage = "request_received"
        event(g.stage, "start", request_id=g.request_id)

    def stage(name):
        g.stage = name
        event(name, "start", request_id=g.request_id)

    def success(**fields):
        event(g.stage, "success", request_id=g.request_id, **fields)

    def check_budget():
        if time.monotonic() - g.started >= REQUEST_SECONDS:
            raise Failure("processing_timeout", 504)

    @app.get("/health")
    def health():
        # Local readiness only: never calls the moderation provider.
        ready = app.config["STARTUP_READY"] and app.config["PROVIDER"] is not None
        return jsonify({"status": "ok" if ready else "unavailable"}), (
            200 if ready else 503
        )

    @app.post("/predict")
    def predict():
        try:
            stage("input_validation")
            target = validate_input(request.get_json())
            success()
            stage("provider_readiness")
            provider = app.config["PROVIDER"]
            if not app.config["STARTUP_READY"] or provider is None:
                raise Failure("moderation_unavailable", 503)
            success()
            stage("image_fetch")
            data = fetcher(target, g.started + REQUEST_SECONDS)
            check_budget()
            success()
            stage("image_decode")
            with decode_image(data) as image:
                check_budget()
                success()
                stage("moderation")
                verdict = provider.moderate(image, g.started + REQUEST_SECONDS)
            check_budget()
            offensive, predictions = validate_verdict(verdict)
            success(**verdict.log_fields)
            stage("moderation_result")
            success(offensive=offensive)
            # user_uid binds the requested image path; it is NOT proof of identity.
            # Return a verdict only. The authenticated Flutter uploader cleans up
            # rejected uploads. Never use caller IDs for Admin SDK deletions.
            return jsonify({"offensive": offensive, "predictions": predictions})
        except Failure as error:
            return failure(error.code, error.status, **error.log_fields)
        except HTTPException as error:
            return failure("invalid_request", error.code or 400)
        except Exception:
            return failure("processing_failed", 503)

    def failure(code, status, **fields):
        event(
            g.stage,
            "failure",
            request_id=g.request_id,
            code=code,
            status=status,
            **fields,
        )
        return jsonify({"error": code, "request_id": g.request_id}), status

    @app.errorhandler(HTTPException)
    def http_error(error):
        return failure("invalid_request", error.code or 400)

    @app.after_request
    def settled(response):
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        event(
            "request_complete",
            "settled",
            request_id=g.request_id,
            status=response.status_code,
            elapsed_ms=round((time.monotonic() - g.started) * 1000),
        )
        return response

    return app
