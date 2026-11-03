import json


def json_response(status_code, body):
    """Build a JSON response in the API Gateway HTTP API (payload 2.0) format."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        # ensure_ascii=False: keep non-ASCII text (e.g. Chinese) as-is instead of \u4e2d escapes
        "body": json.dumps(body, ensure_ascii=False),
    }
