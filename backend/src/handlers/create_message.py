import base64
import json
import os
import uuid
from datetime import UTC, datetime

import boto3
from aws_lambda_powertools import Logger, Tracer

from handlers.http import json_response

logger = Logger()
tracer = Tracer()  # Records boto3 (DynamoDB) calls as X-Ray subsegments

TABLE_NAME = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(TABLE_NAME)

BOARD_PK = "BOARD#main"
DEFAULT_AUTHOR = "Anonymous"
MAX_AUTHOR_LEN = 30
MAX_MESSAGE_LEN = 500


def parse_body(event):
    """Parse the request body into a dict; return None if it is not a JSON object."""
    raw = event.get("body") or ""
    # API Gateway may Base64-encode the body; decode it first
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def validate(data):
    """Validate and clean the fields. Returns (fields, error); exactly one is None."""
    author = data.get("author") or ""
    message = data.get("message") or ""

    if not isinstance(author, str) or not isinstance(message, str):
        return None, "author and message must be strings"

    author = author.strip() or DEFAULT_AUTHOR
    message = message.strip()

    if not message:
        return None, "message must not be empty"
    if len(author) > MAX_AUTHOR_LEN:
        return None, f"author must be at most {MAX_AUTHOR_LEN} characters"
    if len(message) > MAX_MESSAGE_LEN:
        return None, f"message must be at most {MAX_MESSAGE_LEN} characters"

    return {"author": author, "message": message}, None


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event, context):
    """POST /api/messages: publish a message."""
    data = parse_body(event)
    if data is None:
        return json_response(400, {"error": "request body must be a JSON object"})

    fields, error = validate(data)
    if error:
        return json_response(400, {"error": error})

    # ISO 8601 UTC timestamp with milliseconds, e.g. 2026-10-27T08:30:00.123Z
    created_at = (
        datetime.now(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    )
    sk = f"{created_at}#{uuid.uuid4()}"

    table.put_item(Item={"PK": BOARD_PK, "SK": sk, **fields})

    # Log the ID only, never the message text: keep user data out of logs (privacy)
    logger.info("message created", extra={"id": sk})

    return json_response(201, {"id": sk, "created_at": created_at, **fields})
