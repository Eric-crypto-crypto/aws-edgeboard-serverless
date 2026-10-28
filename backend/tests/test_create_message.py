import base64
import json

import pytest
from boto3.dynamodb.conditions import Key


def post(handler, ctx, body):
    """模拟一次 POST 请求。body 是字典时转为 JSON，是字符串时原样发送。"""
    raw = body if isinstance(body, str) else json.dumps(body)
    resp = handler.handler({"body": raw}, ctx)
    return resp["statusCode"], json.loads(resp["body"])


def stored_items(table):
    return table.query(KeyConditionExpression=Key("PK").eq("BOARD#main"))["Items"]


def test_valid_message_is_created_and_stored(load_handler, lambda_context, table):
    create = load_handler("handlers.create_message")

    status, body = post(create, lambda_context, {"author": "Eric", "message": "Hello"})

    assert status == 201
    assert body["author"] == "Eric"
    assert body["message"] == "Hello"
    assert body["id"].startswith(body["created_at"] + "#")
    items = stored_items(table)
    assert len(items) == 1
    assert items[0]["SK"] == body["id"]


def test_message_and_author_are_stripped(load_handler, lambda_context):
    create = load_handler("handlers.create_message")

    _, body = post(create, lambda_context, {"author": "  Eric  ", "message": "  Hi \n"})

    assert body["author"] == "Eric"
    assert body["message"] == "Hi"


@pytest.mark.parametrize(
    "data", [{"message": "Hi"}, {"author": "   ", "message": "Hi"}]
)
def test_author_defaults_to_anonymous(load_handler, lambda_context, data):
    create = load_handler("handlers.create_message")

    _, body = post(create, lambda_context, data)

    assert body["author"] == "匿名"


@pytest.mark.parametrize(
    "body",
    [
        "not json",
        "[1, 2, 3]",
        {},
        {"message": ""},
        {"message": "   "},
        {"message": 123},
        {"message": "x" * 501},
        {"author": "a" * 31, "message": "Hi"},
    ],
)
def test_invalid_input_is_rejected(load_handler, lambda_context, table, body):
    create = load_handler("handlers.create_message")

    status, resp_body = post(create, lambda_context, body)

    assert status == 400
    assert "error" in resp_body
    assert stored_items(table) == []  # 被拒绝的请求不能写入任何数据


def test_max_length_message_is_accepted(load_handler, lambda_context):
    create = load_handler("handlers.create_message")

    status, _ = post(create, lambda_context, {"message": "x" * 500})

    assert status == 201


def test_html_is_stored_as_plain_text(load_handler, lambda_context, table):
    create = load_handler("handlers.create_message")
    payload = "<script>alert(1)</script>"

    post(create, lambda_context, {"message": payload})

    # 后端原样存储，XSS 防护由前端的 textContent 负责
    assert stored_items(table)[0]["message"] == payload


def test_base64_encoded_body_is_decoded(load_handler, lambda_context):
    create = load_handler("handlers.create_message")
    raw = base64.b64encode(json.dumps({"message": "你好"}).encode()).decode()

    resp = create.handler({"body": raw, "isBase64Encoded": True}, lambda_context)

    assert resp["statusCode"] == 201
    assert json.loads(resp["body"])["message"] == "你好"
