"""Production startup: AWS Rekognition moderation, no local model or Torch.

Startup builds the AWS client locally and makes no AWS request. Missing or
invalid AWS configuration leaves /health at 503 and /predict fail-closed.
The deprecated local YOLO checkpoint lives in legacy_yolo/ and is not used here.
"""

import os

from service import create_app, event

# Render is not EC2: skip instance-metadata credential discovery, which would
# only add network timeouts when environment credentials are absent.
os.environ.setdefault("AWS_EC2_METADATA_DISABLED", "true")
STARTUP_CODES = {"aws_region_missing_or_invalid", "aws_credentials_missing"}


def load_provider():
    from rekognition_provider import load_provider as load_rekognition

    return load_rekognition(os.environ)


def build_app(*, provider_loader=load_provider):
    stage = "provider_readiness"
    try:
        event(stage, "start")
        provider = provider_loader()
        event(stage, "success")
        return create_app(provider=provider)
    except Exception as error:
        # Only fixed codes from this codebase are logged, never exception text.
        code = str(error) if isinstance(error, RuntimeError) else ""
        event(
            stage,
            "failure",
            code=code if code in STARTUP_CODES else "initialization_failed",
        )
        # Process stays inspectable; health is 503 and prediction cannot approve.
        return create_app(startup_ready=False)
