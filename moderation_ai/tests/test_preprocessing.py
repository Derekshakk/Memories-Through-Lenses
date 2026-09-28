from io import BytesIO

import pytest
from PIL import Image
from service import create_app, decode_image
from test_service import Provider, payload


@pytest.mark.parametrize(
    "fmt,mode", [("PNG", "RGB"), ("PNG", "RGBA"), ("JPEG", "RGB"), ("PNG", "L")]
)
def test_decode_preserves_detail_dimensions_and_rgb_channels(fmt, mode):
    color = {"RGB": (230, 15, 70), "RGBA": (230, 15, 70, 255), "L": 73}[mode]
    source = Image.new(mode, (1170, 646), color)
    buffer = BytesIO()
    source.save(buffer, format=fmt)
    data = buffer.getvalue()
    with Image.open(BytesIO(data)) as original, decode_image(data) as decoded:
        assert decoded.size == (1170, 646)
        assert decoded.mode == "RGB"
        assert decoded.tobytes() == original.convert("RGB").tobytes()


def test_small_details_are_not_destroyed_by_64_pixel_resize():
    with Image.new("RGB", (1170, 646), "white") as source:
        source.putpixel((583, 322), (0, 0, 255))
        buffer = BytesIO()
        source.save(buffer, format="PNG")
    with decode_image(buffer.getvalue()) as decoded:
        assert decoded.getpixel((583, 322)) == (0, 0, 255)
        assert decoded.getpixel((584, 322)) == (255, 255, 255)


def test_exif_orientation_is_applied_before_moderation():
    with Image.new("RGB", (120, 80), "red") as source:
        exif = Image.Exif()
        exif[274] = 6
        buffer = BytesIO()
        source.save(buffer, format="JPEG", exif=exif)
    with decode_image(buffer.getvalue()) as decoded:
        assert decoded.size == (80, 120)
        assert decoded.getexif().get(274) is None


def test_predict_passes_native_dimensions_to_provider():
    buffer = BytesIO()
    Image.new("RGB", (1170, 646), "blue").save(buffer, format="PNG")
    provider = Provider()
    response = (
        create_app(provider=provider, fetcher=lambda *_: buffer.getvalue())
        .test_client()
        .post("/predict", json=payload())
    )
    assert response.status_code == 200
    assert provider.images == [(1170, 646)]
