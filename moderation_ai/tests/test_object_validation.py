"""Regression coverage for historical MemoLens filenames and exact URL binding."""

from types import SimpleNamespace
from unittest.mock import Mock
from urllib.parse import quote, unquote, urlsplit

import pytest
from service import create_app, validate_input
from test_service import Model, photo

UID = "Y7fJd2xMOfXIHYniYAKOzu8ektO2"
HISTORICAL_NAME = "2026-03-11 10:34:12.468949"
BASE = (
    "https://firebasestorage.googleapis.com/v0/b/memories-through-lenses.appspot.com/o/"
)


def body(uid=UID, name=HISTORICAL_NAME):
    return {
        "user_uid": uid,
        "image_name": name,
        "url": BASE
        + quote(f"posts/{uid}/{name}", safe="")
        + "?alt=media&token=test-token",
    }


@pytest.mark.parametrize(
    "name",
    [
        HISTORICAL_NAME,
        "post123",
        "post-123_ABC",
        "photo.jpg",
        "Screenshot 2026-09-27.png",
        "caf\u00e9.png",
        "image+edited.jpg",
        "a" * 255,
    ],
)
def test_reasonable_filenames_have_exact_canonical_paths(name):
    target = validate_input(body(name=name))
    assert (
        unquote(urlsplit(target).path)
        == f"/v0/b/memories-through-lenses.appspot.com/o/posts/{UID}/{name}"
    )


@pytest.mark.parametrize("offensive", [False, True])
def test_exact_production_identity_local_predict_contract(offensive):
    boxes = [SimpleNamespace(cls=4, conf=0.9)] if offensive else []
    model = Model(boxes)
    fetcher = Mock(return_value=photo())
    app = create_app(model=model, fetcher=fetcher)
    response = app.test_client().post("/predict", json=body())
    assert response.status_code == 200
    assert response.json == {
        "offensive": offensive,
        "predictions": [{"class": "weapons", "confidence": 0.9}] if offensive else [],
    }
    assert model.calls == 1
    assert fetcher.call_count == 1
    assert fetcher.call_args.args[0] == validate_input(body())


@pytest.mark.parametrize("field", ["user_uid", "image_name"])
def test_field_must_match_url_exactly(field):
    payload = body()
    payload[field] = "another-valid-value"
    fetcher = Mock()
    app = create_app(model=Model(), fetcher=fetcher)
    response = app.test_client().post("/predict", json=payload)
    assert response.status_code == 400
    assert response.json["error"] == "object_identity_mismatch"
    fetcher.assert_not_called()
    assert app.config["MODEL"].calls == 0


@pytest.mark.parametrize("field", ["user_uid", "image_name"])
@pytest.mark.parametrize(
    "value",
    [
        "../photo",
        "..",
        ".",
        "a/b",
        "a\\b",
        "%2e%2e%2fphoto",
        "%252e%252e%252fphoto",
        "a%2fb",
        "a%5cb",
        "a%00b",
        "a\x00b",
        "a\nb",
        "a\rb",
        "a\tb",
        "a\x7fb",
        "a\x85b",
        "a\u202eb",
        "a\ud800b",
        " leading",
        "trailing ",
        " ",
        "a" * 256,
    ],
)
def test_unsafe_identity_cannot_be_authorized_by_matching_url(field, value):
    # Deliberately match URL to the dangerous field; equality alone is unsafe.
    payload = body()
    payload[field] = value
    payload["url"] = (
        BASE
        + quote(
            f"posts/{payload['user_uid']}/{payload['image_name']}",
            safe="",
            errors="surrogatepass",
        )
        + "?alt=media&token=test-token"
    )
    fetcher = Mock()
    app = create_app(model=Model(), fetcher=fetcher)
    response = app.test_client().post("/predict", json=payload)
    assert response.status_code == 400
    assert "offensive" not in response.json
    fetcher.assert_not_called()


@pytest.mark.parametrize(
    "encoded",
    [
        "posts%2F" + UID + "%2F%2e%2e%2Fphoto",
        "posts%2F" + UID + "%2F%252e%252e%252fphoto",
        "posts%2F" + UID + "%2Fphoto%2Fextra",
        "posts%2F" + UID + "%2Fphoto%5Cextra",
        "posts%2F" + UID + "%2Fphoto%00",
        "posts%2F" + UID + "%2Fphoto%",
        "posts%2F" + UID + "%2Fphoto%2",
        "posts%2F" + UID + "%2Fphoto%GG",
        "posts%2F" + UID + "%2Fphoto%FF",
        "posts%2F" + UID + "%2Fphoto%C0%AF",
        "posts%2F" + UID + "%2Fphoto%ED%A0%80",
        "posts%252F" + UID + "%252Fphoto",
        "posts/" + UID + "/photo",
        "posts%2F%2Fphoto",
        "posts%2F" + UID + "%2F",
        "other%2F" + UID + "%2Fphoto",
    ],
)
def test_malformed_or_traversing_url_is_rejected_before_fetch(encoded):
    payload = body()
    payload["url"] = BASE + encoded + "?alt=media&token=test-token"
    fetcher = Mock()
    app = create_app(model=Model(), fetcher=fetcher)
    response = app.test_client().post("/predict", json=payload)
    assert response.status_code == 400
    fetcher.assert_not_called()


@pytest.mark.parametrize(
    "old,new",
    [
        ("memories-through-lenses.appspot.com", "wrong.appspot.com"),
        ("firebasestorage.googleapis.com", "evil.example"),
    ],
)
def test_historical_name_does_not_relax_host_or_bucket(old, new):
    payload = body()
    payload["url"] = payload["url"].replace(old, new)
    fetcher = Mock()
    app = create_app(model=Model(), fetcher=fetcher)
    assert app.test_client().post("/predict", json=payload).status_code == 400
    fetcher.assert_not_called()


def test_encoded_path_is_decoded_once_without_normalization():
    payload = body(name="caf\u00e9.png")
    payload["url"] = body(name="cafe\u0301.png")["url"]
    from service import Failure

    with pytest.raises(Failure, match="object_identity_mismatch"):
        validate_input(payload)
