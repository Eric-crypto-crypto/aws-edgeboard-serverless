import base64
import json
import os
import uuid
from datetime import UTC, datetime

import boto3
from aws_lambda_powertools import Logger

from handlers.http import json_response

logger = Logger()

TABLE_NAME = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(TABLE_NAME)

BOARD_PK = "BOARD#main"
DEFAULT_AUTHOR = "匿名"
MAX_AUTHOR_LEN = 30
MAX_MESSAGE_LEN = 500


def parse_body(event):
    """把请求体解析为字典；不是合法的 JSON 对象时返回 None。"""
    raw = event.get("body") or ""
    # API Gateway 有时会把请求体做 Base64 编码后再传进来，需要先解码
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def validate(data):
    """校验并清洗字段，返回 (清洗后的字段, 错误信息)，两者必有一个为 None。"""
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
def handler(event, context):
    """POST /api/messages：发布一条留言。"""
    data = parse_body(event)
    if data is None:
        return json_response(400, {"error": "request body must be a JSON object"})

    fields, error = validate(data)
    if error:
        return json_response(400, {"error": error})

    # ISO 8601 UTC 时间，精确到毫秒，例如 2026-10-27T08:30:00.123Z
    created_at = (
        datetime.now(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    )
    sk = f"{created_at}#{uuid.uuid4()}"

    table.put_item(Item={"PK": BOARD_PK, "SK": sk, **fields})

    # 只记录 ID，不记录留言内容：日志里不要存放用户数据（隐私）
    logger.info("message created", extra={"id": sk})

    return json_response(201, {"id": sk, "created_at": created_at, **fields})
