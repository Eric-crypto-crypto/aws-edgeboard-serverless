import importlib
from dataclasses import dataclass

import boto3
import pytest
from moto import mock_aws

TABLE_NAME = "edgeboard-test"


@pytest.fixture
def aws_env(monkeypatch):
    """设置假的 AWS 环境，确保测试绝对不会连接到真实的 AWS 账号。"""
    monkeypatch.setenv("AWS_DEFAULT_REGION", "ap-southeast-2")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    monkeypatch.setenv("TABLE_NAME", TABLE_NAME)
    monkeypatch.setenv("POWERTOOLS_SERVICE_NAME", "edgeboard-test")
    monkeypatch.setenv("POWERTOOLS_TRACE_DISABLED", "true")  # 测试时不向 X-Ray 发送数据


@pytest.fixture
def table(aws_env):
    """在 moto 模拟环境中创建一张和真实表结构相同的表。"""
    with mock_aws():
        t = boto3.resource("dynamodb").create_table(
            TableName=TABLE_NAME,
            KeySchema=[
                {"AttributeName": "PK", "KeyType": "HASH"},
                {"AttributeName": "SK", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "PK", "AttributeType": "S"},
                {"AttributeName": "SK", "AttributeType": "S"},
            ],
            BillingMode="PAY_PER_REQUEST",
        )
        yield t


@dataclass
class FakeLambdaContext:
    """模拟 Lambda 的 context 对象（Powertools Logger 需要读取这些字段）。"""

    function_name: str = "test-fn"
    memory_limit_in_mb: int = 128
    invoked_function_arn: str = (
        "arn:aws:lambda:ap-southeast-2:123456789012:function:test-fn"
    )
    aws_request_id: str = "test-request-id"


@pytest.fixture
def lambda_context():
    return FakeLambdaContext()


@pytest.fixture
def load_handler(table):
    """在 moto 环境就绪之后，再（重新）导入 handler 模块。"""

    def _load(module_name):
        module = importlib.import_module(module_name)
        return importlib.reload(module)

    return _load
