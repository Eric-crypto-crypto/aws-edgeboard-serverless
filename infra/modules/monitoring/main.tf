# ===== 1. SNS topic + email subscription =====
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  # Settings shared by every alarm
  alarm_defaults = {
    period              = 300 # 5-minute periods
    evaluation_periods  = 1
    threshold           = 1
    comparison_operator = "GreaterThanOrEqualToThreshold"
    statistic           = "Sum"
    treat_missing_data  = "notBreaching" # No traffic means no errors: treat as OK
  }
}

# ===== 2. Lambda error alarms (one per function) =====
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_functions

  alarm_name        = "${var.name}-lambda-${each.key}-errors"
  alarm_description = "Lambda ${each.value} had unhandled errors in the last 5 minutes"
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

# ===== 3. API 5xx alarm =====
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name        = "${var.name}-api-5xx"
  alarm_description = "The API returned 5xx errors in the last 5 minutes"
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

# ===== 4. DynamoDB throttling alarms (read and write) =====
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  for_each = toset(["ReadThrottleEvents", "WriteThrottleEvents"])

  alarm_name        = "${var.name}-dynamodb-${each.key}"
  alarm_description = "DynamoDB table ${var.table_name} reported ${each.key}"
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
