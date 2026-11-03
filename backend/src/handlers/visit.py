import os

import boto3
from aws_lambda_powertools import Logger, Tracer

from handlers.http import json_response

# ===== Runs once per cold start; warm invocations reuse it =====
logger = Logger()
tracer = Tracer()  # Records boto3 (DynamoDB) calls as X-Ray subsegments

# Table name comes from an env var, so the same code serves dev and prod
TABLE_NAME = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(TABLE_NAME)

# Full primary key: the table has a sort key, so both PK and SK are required
COUNTER_KEY = {"PK": "COUNTER#site", "SK": "COUNTER#site"}


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event, context):
    """POST /api/visit: increment the visit counter and return the new value."""
    resp = table.update_item(
        Key=COUNTER_KEY,
        UpdateExpression="ADD visits :inc",
        ExpressionAttributeValues={":inc": 1},
        ReturnValues="UPDATED_NEW",
    )

    # boto3 returns numbers as Decimal, which json.dumps cannot serialize; use int
    visits = int(resp["Attributes"]["visits"])
    logger.info("visit counted", extra={"visits": visits})

    return json_response(200, {"visits": visits})
