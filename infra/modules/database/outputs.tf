output "table_name" {
  description = "Table name, injected into Lambda as an environment variable"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "Table ARN, used for least-privilege IAM policies"
  value       = aws_dynamodb_table.this.arn
}
