import base64
import json
import os

import boto3
from aws_lambda_powertools import Logger, Tracer
from boto3.dynamodb.conditions import Key

from handlers.http import json_response

logger = Logger()
tracer = Tracer()  # Records boto3 (DynamoDB) calls as X-Ray subsegments

TABLE_NAME = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(TABLE_NAME)

BOARD_PK = "BOARD#main"
PAGE_SIZE = 20


def encode_cursor(last_key):
    """Encode LastEvaluatedKey as a URL-safe string for the frontend."""
    return base64.urlsafe_b64encode(json.dumps(last_key).encode()).decode()


def decode_cursor(cursor):
    """Decode a cursor from the frontend; None if malformed or for another partition."""
    if not isinstance(cursor, str):
        return None
    try:
        key = json.loads(base64.urlsafe_b64decode(cursor.encode()))
    except (ValueError, UnicodeDecodeError):
        return None

    # The cursor is user input too: reject keys tampered to point at other partitions
    if (
        not isinstance(key, dict)
        or set(key) != {"PK", "SK"}
        or key["PK"] != BOARD_PK
        or not isinstance(key["SK"], str)
    ):
        return None
    return key


def to_message(item):
    """Convert a table item into the API shape, hiding internals such as PK/SK."""
    return {
        "id": item["SK"],
        "author": item.get("author", ""),
        "message": item.get("message", ""),
        "created_at": item["SK"].split("#", 1)[0],
    }


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event, context):
    """GET /api/messages?cursor=...: list messages newest first, paginated."""
    params = event.get("queryStringParameters") or {}

    query_kwargs = {
        "KeyConditionExpression": Key("PK").eq(BOARD_PK),
        "ScanIndexForward": False,  # Descending: newest first
        "Limit": PAGE_SIZE,
    }

    if "cursor" in params:
        start_key = decode_cursor(params["cursor"])
        if start_key is None:
            return json_response(400, {"error": "invalid cursor"})
        query_kwargs["ExclusiveStartKey"] = start_key

    resp = table.query(**query_kwargs)

    last_key = resp.get("LastEvaluatedKey")
    return json_response(
        200,
        {
            "messages": [to_message(item) for item in resp["Items"]],
            "next_cursor": encode_cursor(last_key) if last_key else None,
        },
    )
