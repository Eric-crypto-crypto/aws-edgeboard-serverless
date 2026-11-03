import importlib
from dataclasses import dataclass

import boto3
import pytest
from moto import mock_aws

TABLE_NAME = "edgeboard-test"


@pytest.fixture
def aws_env(monkeypatch):
    """Fake AWS environment so tests can never reach a real AWS account."""
    monkeypatch.setenv("AWS_DEFAULT_REGION", "ap-southeast-2")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    monkeypatch.setenv("TABLE_NAME", TABLE_NAME)
    monkeypatch.setenv("POWERTOOLS_SERVICE_NAME", "edgeboard-test")
    # Don't send traces to X-Ray in tests
    monkeypatch.setenv("POWERTOOLS_TRACE_DISABLED", "true")


@pytest.fixture
def table(aws_env):
    """Create a moto table with the same schema as the real one."""
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
    """Fake Lambda context object (Powertools Logger reads these fields)."""

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
    """(Re)import a handler module once the moto environment is ready."""

    def _load(module_name):
        module = importlib.import_module(module_name)
        return importlib.reload(module)

    return _load
