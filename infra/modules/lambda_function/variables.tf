variable "function_name" {
  description = "Lambda 函数名，例如 edgeboard-dev-visit"
  type        = string
}

variable "handler" {
  description = "入口函数，格式为 <模块路径>.<函数名>，例如 handlers.visit.handler"
  type        = string
}

variable "filename" {
  description = "代码 zip 包的本地路径"
  type        = string
}

variable "source_code_hash" {
  description = "代码包的哈希值：代码变化时触发重新部署"
  type        = string
}

variable "environment" {
  description = "注入函数的环境变量"
  type        = map(string)
  default     = {}
}

variable "layers" {
  description = "Lambda Layer ARN 列表"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arn" {
  description = "函数允许访问的 DynamoDB 表 ARN"
  type        = string
}

variable "dynamodb_actions" {
  description = "允许执行的 DynamoDB 操作（最小权限），例如 [\"dynamodb:Query\"]"
  type        = list(string)
}

variable "timeout" {
  description = "超时时间（秒）"
  type        = number
  default     = 5
}

variable "memory_size" {
  description = "内存（MB）。CPU 与内存成正比"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "日志保留天数"
  type        = number
  default     = 14
}
