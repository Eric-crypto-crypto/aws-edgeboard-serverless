import base64
import json


def put_messages(table, count):
    """按时间顺序写入 count 条留言：Hello #0 最早，Hello #(count-1) 最新。"""
    for i in range(count):
        table.put_item(
            Item={
                "PK": "BOARD#main",
                "SK": f"2026-10-27T00:00:{i:02d}.000Z#id{i:02d}",
                "author": "tester",
                "message": f"Hello #{i}",
            }
        )


def get(handler, ctx, params=None):
    resp = handler.handler({"queryStringParameters": params}, ctx)
    return resp["statusCode"], json.loads(resp["body"])


def make_cursor(key):
    return base64.urlsafe_b64encode(json.dumps(key).encode()).decode()


def test_empty_board_returns_no_messages(load_handler, lambda_context):
    list_messages = load_handler("handlers.list_messages")

    status, body = get(list_messages, lambda_context)

    assert status == 200
    assert body == {"messages": [], "next_cursor": None}


def test_messages_are_newest_first(load_handler, lambda_context, table):
    put_messages(table, 3)
    list_messages = load_handler("handlers.list_messages")

    _, body = get(list_messages, lambda_context)

    assert [m["message"] for m in body["messages"]] == [
        "Hello #2",
        "Hello #1",
        "Hello #0",
    ]
    assert body["messages"][0]["created_at"] == "2026-10-27T00:00:02.000Z"


def test_pagination_with_cursor(load_handler, lambda_context, table):
    put_messages(table, 25)
    list_messages = load_handler("handlers.list_messages")

    _, page1 = get(list_messages, lambda_context)
    _, page2 = get(list_messages, lambda_context, {"cursor": page1["next_cursor"]})

    assert len(page1["messages"]) == 20
    assert page1["messages"][0]["message"] == "Hello #24"
    assert page1["next_cursor"] is not None
    assert [m["message"] for m in page2["messages"]] == [
        f"Hello #{i}" for i in range(4, -1, -1)
    ]
    assert page2["next_cursor"] is None


def test_counter_item_is_not_returned(load_handler, lambda_context, table):
    table.put_item(Item={"PK": "COUNTER#site", "SK": "COUNTER#site", "visits": 42})
    put_messages(table, 1)
    list_messages = load_handler("handlers.list_messages")

    _, body = get(list_messages, lambda_context)

    assert len(body["messages"]) == 1


def test_malformed_cursor_is_rejected(load_handler, lambda_context):
    list_messages = load_handler("handlers.list_messages")

    status, _ = get(list_messages, lambda_context, {"cursor": "not-a-valid-cursor!!"})

    assert status == 400


def test_cursor_pointing_to_other_partition_is_rejected(load_handler, lambda_context):
    list_messages = load_handler("handlers.list_messages")
    tampered = make_cursor({"PK": "COUNTER#site", "SK": "COUNTER#site"})

    status, _ = get(list_messages, lambda_context, {"cursor": tampered})

    assert status == 400
