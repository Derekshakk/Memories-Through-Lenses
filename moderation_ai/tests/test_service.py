import json
import logging
from io import BytesIO
from types import SimpleNamespace
from unittest.mock import Mock
from urllib.parse import quote

import pytest
import service
import urllib3
from PIL import Image
from service import Failure, create_app, decode_image, fetch_image, validate_input


def photo(fmt="JPEG", size=(64, 48)):
    output = BytesIO()
    with Image.new("RGB", size, "blue") as image:
        image.save(output, format=fmt)
    return output.getvalue()


def payload():
    return {
        "url": "https://firebasestorage.googleapis.com/v0/b/memories-through-lenses.appspot.com/o/"
        + quote("posts/user-1/post-1", safe="")
        + "?alt=media&token=private-download-token",
        "user_uid": "user-1",
        "image_name": "post-1",
    }


class Model:
    names = {0: "adult", 1: "racism", 2: "substance", 3: "violence", 4: "weapons"}

    def __init__(self, boxes=()):
        self.boxes = boxes
        self.calls = 0

    def __call__(self, images, verbose=False):
        self.calls += 1
        assert images[0].size == (64, 64)
        assert images[0].mode == "RGB"
        return [SimpleNamespace(boxes=self.boxes)]


@pytest.fixture
def app():
    return create_app(model=Model(), fetcher=lambda *_: photo())


def test_health(app):
    response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.json == {"status": "ok"}
    assert response.headers["Cache-Control"] == "no-store"


@pytest.mark.parametrize("field", ["url", "user_uid", "image_name"])
@pytest.mark.parametrize("value", [None, "", 123, [], {}])
def test_missing_or_invalid_fields(app, field, value):
    body = payload()
    body[field] = value
    response = app.test_client().post("/predict", json=body)
    assert response.status_code == 400
    assert "offensive" not in response.json
    assert app.config["MODEL"].calls == 0


@pytest.mark.parametrize("body", [None, [], "text", {}, True])
def test_non_object_or_missing_body(app, body):
    response = app.test_client().post(
        "/predict", data=json.dumps(body), content_type="application/json"
    )
    assert response.status_code == 400


def test_bad_json_and_content_type(app):
    client = app.test_client()
    assert (
        client.post("/predict", data="{", content_type="application/json").status_code
        == 400
    )
    assert client.post("/predict", data="hello").status_code == 415
    assert (
        client.post(
            "/predict", data="x" * 9000, content_type="application/json"
        ).status_code
        == 413
    )


@pytest.mark.parametrize(
    "url",
    [
        "http://firebasestorage.googleapis.com/test",
        "file:///etc/passwd",
        "https://localhost/image",
        "https://127.0.0.1/image",
        "https://[::1]/image",
        "https://169.254.169.254/latest/meta-data",
        "https://10.0.0.1/image",
        "https://192.168.1.1/image",
        "https://evil.example/image",
        "https://firebasestorage.googleapis.com.evil.example/image",
        "https://firebasestorage.googleapis.com@evil.example/image",
        "https://evil@firebasestorage.googleapis.com/test",
        "https://firebasestorage.googleapis.com:5001/test",
        "not a url",
        " https://firebasestorage.googleapis.com/test",
        "https://firebasestorage.googleapis.com/test#fragment",
        "https://firebasestorage.googleapis.com/\nimage",
    ],
)
def test_disallowed_urls(app, url):
    body = payload()
    body["url"] = url
    response = app.test_client().post("/predict", json=body)
    assert response.status_code == 400
    assert app.config["MODEL"].calls == 0


@pytest.mark.parametrize(
    "change",
    [
        lambda p: p.update(user_uid="different-user"),
        lambda p: p.update(image_name="../post-1"),
        lambda p: p.update(user_uid="user/other"),
        lambda p: p.update(
            url=p["url"].replace(
                "memories-through-lenses.appspot.com", "other.appspot.com"
            )
        ),
        lambda p: p.update(url=p["url"].replace("posts%2F", "profiles%2F")),
        lambda p: p.update(url=p["url"].replace("posts%2F", "posts%252F")),
        lambda p: p.update(url=p["url"] + "&redirect=https://localhost"),
        lambda p: p.update(url=p["url"] + "&token=second"),
        lambda p: p.update(url=p["url"].replace("alt=media", "alt=json")),
        lambda p: p.update(url=p["url"].split("&token")[0]),
    ],
)
def test_scoped_object_and_download_query(app, change):
    body = payload()
    change(body)
    assert app.test_client().post("/predict", json=body).status_code == 400


def test_model_not_ready():
    fetcher = Mock()
    app = create_app(fetcher=fetcher)
    assert app.test_client().get("/health").status_code == 503
    response = app.test_client().post("/predict", json=payload())
    assert response.status_code == 503
    assert response.json["error"] == "model_unavailable"
    fetcher.assert_not_called()


@pytest.mark.parametrize("fmt", ["JPEG", "PNG"])
def test_benign(fmt):
    app = create_app(model=Model(), fetcher=lambda *_: photo(fmt))
    response = app.test_client().post("/predict", json=payload())
    assert response.status_code == 200
    assert response.json == {"offensive": False, "predictions": []}


@pytest.mark.parametrize("confidence,offensive", [(0.7, False), (0.71, True)])
def test_offensive_threshold(confidence, offensive):
    model = Model([SimpleNamespace(cls=4, conf=confidence)])
    app = create_app(model=model, fetcher=lambda *_: photo())
    response = app.test_client().post("/predict", json=payload())
    assert response.status_code == 200
    assert response.json == {
        "offensive": offensive,
        "predictions": [{"class": "weapons", "confidence": confidence}],
    }


@pytest.mark.parametrize(
    "failure", [Failure("image_fetch_failed", 502), Failure("image_fetch_timeout", 504)]
)
def test_fetch_failure(failure):
    app = create_app(model=Model(), fetcher=Mock(side_effect=failure))
    response = app.test_client().post("/predict", json=payload())
    assert response.status_code == failure.status
    assert "offensive" not in response.json


def test_inference_failure():
    model = Mock(side_effect=RuntimeError("private-token-do-not-log"))
    app = create_app(model=model, fetcher=lambda *_: photo())
    response = app.test_client().post("/predict", json=payload())
    assert response.status_code == 503
    assert "offensive" not in response.json
    assert b"private-token" not in response.data


@pytest.mark.parametrize(
    "boxes",
    [
        None,
        [SimpleNamespace(cls=0, conf=float("nan"))],
        [SimpleNamespace(cls=-1, conf=0.9)],
        [SimpleNamespace(cls=99, conf=0.9)],
    ],
)
def test_invalid_model_output_never_approves(boxes):
    app = create_app(model=Model(boxes), fetcher=lambda *_: photo())
    assert app.test_client().post("/predict", json=payload()).status_code == 503


@pytest.mark.parametrize(
    "data", [b"bad image", b"", b"\xff\xd8truncated", photo("GIF")]
)
def test_malformed_or_unsupported_image(data):
    app = create_app(model=Model(), fetcher=lambda *_: data)
    response = app.test_client().post("/predict", json=payload())
    assert response.status_code == 422
    assert app.config["MODEL"].calls == 0


def test_pixel_limit(monkeypatch):
    monkeypatch.setattr(service, "MAX_IMAGE_PIXELS", 100)
    with pytest.raises(Failure) as caught:
        decode_image(photo())
    assert caught.value.status == 413


def test_slow_inference_returns_timeout_not_approval(monkeypatch):
    now = [0.0]
    monkeypatch.setattr(service.time, "monotonic", lambda: now[0])

    class Slow(Model):
        def __call__(self, *args, **kwargs):
            now[0] = 12.0
            return super().__call__(*args, **kwargs)

    response = (
        create_app(model=Slow(), fetcher=lambda *_: photo())
        .test_client()
        .post("/predict", json=payload())
    )
    assert response.status_code == 504
    assert "offensive" not in response.json


def test_logs_are_structured_and_redacted():
    messages = []

    class Capture(logging.Handler):
        def emit(self, record):
            messages.append(json.loads(record.getMessage()))

    handler = Capture()
    service.logger.addHandler(handler)
    try:
        model = Mock(side_effect=RuntimeError("secret-service-account"))
        app = create_app(model=model, fetcher=lambda *_: photo())
        app.test_client().post(
            "/predict", json=payload(), headers={"Authorization": "secret-auth-header"}
        )
    finally:
        service.logger.removeHandler(handler)
    serialized = json.dumps(messages)
    for secret in [
        "private-download-token",
        "secret-service-account",
        "secret-auth-header",
        "user-1",
        "post-1",
        "https://",
    ]:
        assert secret not in serialized
    assert any(e["stage"] == "inference" and e["event"] == "failure" for e in messages)


@pytest.fixture
def transport(monkeypatch):
    response = Mock(status=200, headers={"Content-Type": "image/jpeg"})
    response.read1.side_effect = [photo(), b""]
    pool = Mock()
    pool.urlopen.return_value = response
    factory = Mock(return_value=pool)
    monkeypatch.setattr(service.urllib3, "HTTPSConnectionPool", factory)
    monkeypatch.setattr(
        service.socket,
        "getaddrinfo",
        lambda *_args, **_kwargs: [(2, 1, 6, "", ("8.8.8.8", 443))],
    )
    return response, pool, factory


def test_pins_public_address_and_keeps_tls_hostname(transport, monkeypatch):
    response, pool, factory = transport
    monkeypatch.setenv("HTTPS_PROXY", "http://127.0.0.1:9000")
    assert (
        fetch_image(validate_input(payload()), service.time.monotonic() + 11) == photo()
    )
    assert factory.call_args.args == ("8.8.8.8",)
    assert factory.call_args.kwargs["server_hostname"] == service.STORAGE_HOST
    assert factory.call_args.kwargs["assert_hostname"] == service.STORAGE_HOST
    assert factory.call_args.kwargs["cert_reqs"] == "CERT_REQUIRED"
    assert pool.urlopen.call_args.kwargs["redirect"] is False
    assert pool.urlopen.call_args.kwargs["retries"] is False
    response.close.assert_called_once()
    pool.close.assert_called_once()


@pytest.mark.parametrize(
    "address",
    ["127.0.0.1", "10.0.0.1", "169.254.169.254", "::1", "fc00::1", "224.0.0.1"],
)
def test_private_dns_answers_never_connect(transport, monkeypatch, address):
    _, _, factory = transport
    monkeypatch.setattr(
        service.socket,
        "getaddrinfo",
        lambda *_args, **_kwargs: [(2, 1, 6, "", (address, 443))],
    )
    with pytest.raises(Failure):
        fetch_image(validate_input(payload()), service.time.monotonic() + 11)
    factory.assert_not_called()


@pytest.mark.parametrize("status", [301, 302, 307, 403, 404, 500])
def test_upstream_status_and_redirect_rejected(transport, status):
    response, pool, _ = transport
    response.status = status
    response.headers["Location"] = "http://169.254.169.254/latest/meta-data"
    with pytest.raises(Failure):
        fetch_image(validate_input(payload()), service.time.monotonic() + 11)
    assert pool.urlopen.call_count == 1
    response.read1.assert_not_called()
    response.close.assert_called_once()


def test_oversized_stream_closes_response(transport, monkeypatch):
    response, pool, _ = transport
    monkeypatch.setattr(service, "MAX_IMAGE_BYTES", 10)
    with pytest.raises(Failure) as caught:
        fetch_image(validate_input(payload()), service.time.monotonic() + 11)
    assert caught.value.status == 413
    response.close.assert_called_once()
    pool.close.assert_called_once()


def test_network_timeout_is_redacted(transport):
    response, pool, _ = transport
    pool.urlopen.side_effect = urllib3.exceptions.ReadTimeoutError(
        None, "secret-token", "secret-address"
    )
    with pytest.raises(Failure) as caught:
        fetch_image(validate_input(payload()), service.time.monotonic() + 11)
    assert str(caught.value) == "image_fetch_timeout"
    pool.close.assert_called_once()


def test_slow_trickle_has_wall_clock_limit(transport, monkeypatch):
    response, _, _ = transport
    now = [0.0]
    monkeypatch.setattr(service.time, "monotonic", lambda: now[0])

    def slow_read(*_args, **_kwargs):
        now[0] += 1.0
        return b"a"

    response.read1.side_effect = slow_read
    with pytest.raises(Failure) as caught:
        fetch_image(validate_input(payload()), 11)
    assert str(caught.value) == "image_fetch_timeout"
    assert response.read1.call_count == 5
