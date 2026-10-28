output "api_endpoint" {
  description = "API 的默认访问地址"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}