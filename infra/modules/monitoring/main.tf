# ===== 1. 广播站：SNS 主题 + 邮件订阅 =====
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  # 所有告警的公共配置
  alarm_defaults = {
    period              = 300 # 每 5 分钟统计一次
    evaluation_periods  = 1
    threshold           = 1
    comparison_operator = "GreaterThanOrEqualToThreshold"
    statistic           = "Sum"
    treat_missing_data  = "notBreaching" # 没有流量 = 没有错误 = 正常
  }
}

# ===== 2. Lambda 错误告警（每个函数一个）=====
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_functions

  alarm_name        = "${var.name}-lambda-${each.key}-errors"
  alarm_description = "Lambda ${each.value} 在 5 分钟内出现未处理的错误"
  namespace         = "AWS/Lambda"
  metric_name       = "Errors"
  dimensions        = { FunctionName = each.value }

  period              = local.alarm_defaults.period
  evaluation_periods  = local.alarm_defaults.evaluation_periods
  threshold           = local.alarm_defaults.threshold
  comparison_operator = local.alarm_defaults.comparison_operator
  statistic           = local.alarm_defaults.statistic
  treat_missing_data  = local.alarm_defaults.treat_missing_data

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# ===== 3. API 5xx 告警 =====
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name        = "${var.name}-api-5xx"
  alarm_description = "API 在 5 分钟内返回了 5xx 错误"
  namespace         = "AWS/ApiGateway"
  metric_name       = "5xx"
  dimensions = {
    ApiId = var.api_id
    Stage = "$default"
  }

  period              = local.alarm_defaults.period
  evaluation_periods  = local.alarm_defaults.evaluation_periods
  threshold           = local.alarm_defaults.threshold
  comparison_operator = local.alarm_defaults.comparison_operator
  statistic           = local.alarm_defaults.statistic
  treat_missing_data  = local.alarm_defaults.treat_missing_data

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# ===== 4. DynamoDB 限流告警（读、写各一个）=====
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  for_each = toset(["ReadThrottleEvents", "WriteThrottleEvents"])

  alarm_name        = "${var.name}-dynamodb-${each.key}"
  alarm_description = "DynamoDB 表 ${var.table_name} 出现 ${each.key}"
  namespace         = "AWS/DynamoDB"
  metric_name       = each.key
  dimensions        = { TableName = var.table_name }

  period              = local.alarm_defaults.period
  evaluation_periods  = local.alarm_defaults.evaluation_periods
  threshold           = local.alarm_defaults.threshold
  comparison_operator = local.alarm_defaults.comparison_operator
  statistic           = local.alarm_defaults.statistic
  treat_missing_data  = local.alarm_defaults.treat_missing_data

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
