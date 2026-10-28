import os

import boto3
from aws_lambda_powertools import Logger

from handlers.http import json_response

# ===== 以下代码在冷启动时只执行一次，之后的热启动直接复用 =====
logger = Logger()

# 表名通过环境变量注入：同一份代码，dev 和 prod 各连各的表
TABLE_NAME = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(TABLE_NAME)

# 完整主键：表有 SK，因此必须同时提供 PK 和 SK
COUNTER_KEY = {"PK": "COUNTER#site", "SK": "COUNTER#site"}


@logger.inject_lambda_context
def handler(event, context):
    """POST /api/visit：访客数 +1，并返回最新值。"""
    resp = table.update_item(
        Key=COUNTER_KEY,
        UpdateExpression="ADD visits :inc",
        ExpressionAttributeValues={":inc": 1},
        ReturnValues="UPDATED_NEW",
    )

    # boto3 返回的数字是 Decimal 类型，json.dumps 无法直接处理，所以先转成 int
    visits = int(resp["Attributes"]["visits"])
    logger.info("visit counted", extra={"visits": visits})

    return json_response(200, {"visits": visits})
