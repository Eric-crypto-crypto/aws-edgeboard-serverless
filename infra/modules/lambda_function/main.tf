# ===== 1. IAM role =====

# Trust policy: only the Lambda service can assume this role
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# ===== 2. Least-privilege permissions =====

data "aws_iam_policy_document" "permissions" {
  # Only the listed actions on the given table
  statement {
    sid       = "DynamoDBAccess"
    actions   = var.dynamodb_actions
    resources = [var.dynamodb_table_arn]
  }

  # Only write to its own log group
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  # X-Ray has no resource-level permissions, so "*" is required; these actions only write traces
  statement {
    sid       = "WriteTraces"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "this" {
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

# ===== 3. CloudWatch log group =====

resource "aws_cloudwatch_log_group" "this" {
  # Lambda always writes to a log group with this name
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

# ===== 4. The Lambda function =====

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn

  runtime       = "python3.13"
  architectures = ["arm64"]
  handler       = var.handler
  timeout       = var.timeout
  memory_size   = var.memory_size

  filename         = var.filename
  source_code_hash = var.source_code_hash
  layers           = var.layers

  environment {
    variables = var.environment
  }

  tracing_config {
    mode = "Active" # Lambda starts traces for sampled requests
  }

  # Create permissions and the log group first so the first invocation can write logs
  depends_on = [
    aws_iam_role_policy.this,
    aws_cloudwatch_log_group.this,
  ]
}
