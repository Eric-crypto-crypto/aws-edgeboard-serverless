# ===== 1. The API =====
resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP" # HTTP API (not WebSocket)
}

# ===== 2. Access log group =====
resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = var.log_retention_days
}

# ===== 3. Stage: the deployed version of the API =====
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default" # Special name: no stage prefix in the URL
  auto_deploy = true       # Redeploy automatically when routes change

  # Throttling for every route
  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  # Access log: one JSON line per request
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

# ===== 4. Integrations: one per route =====
resource "aws_apigatewayv2_integration" "this" {
  for_each = var.routes

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY" # Pass the whole request through to Lambda
  integration_uri        = each.value.invoke_arn
  payload_format_version = "2.0"
}

# ===== 5. Routes: matched on method + path =====
resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key # e.g. "POST /api/visit"
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
}

# ===== 6. Lambda resource policy: only this route of this API may invoke =====
resource "aws_lambda_permission" "this" {
  for_each = var.routes

  statement_id  = "AllowApiGateway-${replace(replace(each.key, " ", "-"), "/", "_")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"

  # Format: <execution ARN>/<stage>/<method>/<path>, e.g. .../*/POST/api/visit
  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/${split(" ", each.key)[0]}${split(" ", each.key)[1]}"
}
