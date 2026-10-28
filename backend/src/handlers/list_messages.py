import base64
import json
import os

import boto3
from aws_lambda_powertools import Logger, Tracer
from boto3.dynamodb.conditions import Key

from handlers.http import json_response

logger = Logger()
tracer = Tracer()  # 自动记录 boto3 调用（DynamoDB）为 X-Ray 子段

TABLE_NAME = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(TABLE_NAME)

BOARD_PK = "BOARD#main"
PAGE_SIZE = 20


def encode_cursor(last_key):
    """把 LastEvaluatedKey（书签）编码成 URL 安全的字符串，交给前端。"""
    return base64.urlsafe_b64encode(json.dumps(last_key).encode()).decode()


def decode_cursor(cursor):
    """解码前端传回的游标；格式错误或指向其他分区时返回 None。"""
    if not isinstance(cursor, str):
        return None
    try:
        key = json.loads(base64.urlsafe_b64decode(cursor.encode()))
    except (ValueError, UnicodeDecodeError):
        return None

    # 游标也是用户输入：必须防止被篡改成其他分区的键
    if (
        not isinstance(key, dict)
        or set(key) != {"PK", "SK"}
        or key["PK"] != BOARD_PK
        or not isinstance(key["SK"], str)
    ):
        return None
    return key


def to_message(item):
    """把数据库里的一条数据转换成 API 返回的格式（隐藏 PK/SK 等内部细节）。"""
    return {
        "id": item["SK"],
        "author": item.get("author", ""),
        "message": item.get("message", ""),
        "created_at": item["SK"].split("#", 1)[0],
    }


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event, context):
    """GET /api/messages?cursor=...：按时间倒序分页读取留言。"""
    params = event.get("queryStringParameters") or {}

    query_kwargs = {
        "KeyConditionExpression": Key("PK").eq(BOARD_PK),
        "ScanIndexForward": False,  # 倒序：最新的在前
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
