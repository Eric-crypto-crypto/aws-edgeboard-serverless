import json


def test_first_visit_returns_1(load_handler, lambda_context):
    visit = load_handler("handlers.visit")

    resp = visit.handler({}, lambda_context)

    assert resp["statusCode"] == 200
    assert json.loads(resp["body"]) == {"visits": 1}


def test_visits_accumulate(load_handler, lambda_context):
    visit = load_handler("handlers.visit")

    for _ in range(3):
        resp = visit.handler({}, lambda_context)

    assert json.loads(resp["body"])["visits"] == 3


def test_counter_is_stored_with_full_key(load_handler, lambda_context, table):
    visit = load_handler("handlers.visit")

    visit.handler({}, lambda_context)

    item = table.get_item(Key={"PK": "COUNTER#site", "SK": "COUNTER#site"})["Item"]
    assert item["visits"] == 1
