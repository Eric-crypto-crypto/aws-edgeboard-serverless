# ===== 1. 工牌：IAM 角色 =====

# 信任策略：只有 Lambda 服务可以佩戴这个角色
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

# ===== 2. 权限清单：最小权限策略 =====

data "aws_iam_policy_document" "permissions" {
  # 只能对指定的表执行指定的操作
  statement {
    sid       = "DynamoDBAccess"
    actions   = var.dynamodb_actions
    resources = [var.dynamodb_table_arn]
  }

  # 只能写入自己的日志组
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

# ===== 3. 工作日志本：CloudWatch 日志组 =====

resource "aws_cloudwatch_log_group" "this" {
  # Lambda 固定把日志写到这个名字的日志组里
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

# ===== 4. 厨师本人：Lambda 函数 =====

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

  # 先准备好权限和日志组，再创建函数，避免函数第一次运行时没有权限写日志
  depends_on = [
    aws_iam_role_policy.this,
    aws_cloudwatch_log_group.this,
  ]
}
