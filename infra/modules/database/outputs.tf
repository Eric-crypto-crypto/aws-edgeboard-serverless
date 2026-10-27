output "table_name" {
  description = "表名，作为环境变量注入 Lambda"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "表的 ARN，用于编写 IAM 最小权限策略"
  value       = aws_dynamodb_table.this.arn
}
