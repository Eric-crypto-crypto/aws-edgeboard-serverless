import json


def json_response(status_code, body):
    """生成 API Gateway HTTP API（payload 2.0）格式的 JSON 响应。"""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        # ensure_ascii=False：中文按原样输出，而不是变成 \u4e2d 这样的转义序列
        "body": json.dumps(body, ensure_ascii=False),
    }
