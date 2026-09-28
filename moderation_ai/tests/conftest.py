"""Hermetic tests: no developer AWS credentials, no real AWS or Internet calls."""

import ipaddress
import socket

import pytest

AWS_ENVIRONMENT = (
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN",
    "AWS_SECURITY_TOKEN",
    "AWS_PROFILE",
    "AWS_DEFAULT_PROFILE",
    "AWS_REGION",
    "AWS_DEFAULT_REGION",
    "AWS_ROLE_ARN",
    "AWS_WEB_IDENTITY_TOKEN_FILE",
    "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI",
    "AWS_CONTAINER_CREDENTIALS_FULL_URI",
    "AWS_ENDPOINT_URL",
    "AWS_ENDPOINT_URL_REKOGNITION",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
)


@pytest.fixture(autouse=True)
def hermetic_aws(monkeypatch, tmp_path):
    for name in AWS_ENVIRONMENT:
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("AWS_CONFIG_FILE", str(tmp_path / "no-aws-config"))
    monkeypatch.setenv("AWS_SHARED_CREDENTIALS_FILE", str(tmp_path / "no-aws-creds"))
    monkeypatch.setenv("AWS_EC2_METADATA_DISABLED", "true")


@pytest.fixture(autouse=True)
def loopback_only_network(monkeypatch):
    original = socket.socket.connect

    def connect(sock, address, *args, **kwargs):
        host = address[0] if isinstance(address, tuple) else address
        try:
            allowed = ipaddress.ip_address(host).is_loopback
        except ValueError:
            allowed = host == "localhost"
        if not allowed:
            raise AssertionError("tests must not open non-loopback connections")
        return original(sock, address, *args, **kwargs)

    monkeypatch.setattr(socket.socket, "connect", connect)
