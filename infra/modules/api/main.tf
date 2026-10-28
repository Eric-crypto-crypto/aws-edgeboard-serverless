# ===== 1. API 本体 =====
resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP" # HTTP API（不是 WebSocket）
}

# ===== 2. 访问日志组（前台登记本）=====
resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = var.log_retention_days
}

# ===== 3. Stage：API 的"发布版本" =====
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default" # 特殊名字：URL 中不带 stage 前缀
  auto_deploy = true       # 路由变化后自动发布

  # 限流：对所有路由生效
  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  # 访问日志：每个请求一行 JSON
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      routeKey           = "$context.routeKey"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      latencyMs          = "$context.responseLatency"
      integrationLatency = "$context.integrationLatency"
      integrationError   = "$context.integrationErrorMessage"
    })
  }
}

# ===== 4. 集成：前台到厨师的传菜通道（每个路由一个）=====
resource "aws_apigatewayv2_integration" "this" {
  for_each = var.routes

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY" # 把整个请求原样交给 Lambda
  integration_uri        = each.value.invoke_arn
  payload_format_version = "2.0"
}

# ===== 5. 路由：根据"方法 + 路径"分派 =====
resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key # 例如 "POST /api/visit"
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}

# ===== 6. Lambda 资源策略：只允许本 API 的这一个路由调用 =====
resource "aws_lambda_permission" "this" {
  for_each = var.routes

  statement_id  = "AllowApiGateway-${replace(replace(each.key, " ", "-"), "/", "_")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"

  # 格式：<API 执行 ARN>/<stage>/<方法>/<路径>，例如 .../*/POST/api/visit
  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/${split(" ", each.key)[0]}${split(" ", each.key)[1]}"
}
