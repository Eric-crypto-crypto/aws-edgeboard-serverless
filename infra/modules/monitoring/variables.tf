variable "name" {
  description = "资源名前缀，例如 edgeboard-dev"
  type        = string
}

variable "alert_email" {
  description = "接收告警通知的邮箱"
  type        = string
  sensitive   = true
}

variable "lambda_functions" {
  description = "需要监控的 Lambda 函数：键为简称，值为函数名"
  type        = map(string)
}

variable "api_id" {
  description = "HTTP API 的 ID"
  type        = string
}

variable "table_name" {
  description = "DynamoDB 表名"
  type        = string
}
