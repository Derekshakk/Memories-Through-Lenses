"""Manual smoke check using disposable images. No embedded URLs or credentials."""

import json
import os
import urllib.error
import urllib.request


def main():
    # Explicit endpoint: never silently send a private image to a default server.
    endpoint = os.environ["MODERATION_TEST_ENDPOINT"]
    data = {
        "url": os.environ["MODERATION_TEST_IMAGE_URL"],
        "user_uid": os.environ["MODERATION_TEST_USER_UID"],
        "image_name": os.environ["MODERATION_TEST_IMAGE_NAME"],
    }
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            result = json.load(response)
            approved = result.get("offensive")
            if not isinstance(approved, bool):
                raise ValueError
            print(json.dumps({"status": response.status, "offensive": approved}))
    except urllib.error.HTTPError as error:
        # Never print the response body or exception text; either can quote tokens.
        print(json.dumps({"status": error.code, "error": "request_failed"}))
        raise SystemExit(1) from None
    except Exception:
        print(json.dumps({"error": "request_failed"}))
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
