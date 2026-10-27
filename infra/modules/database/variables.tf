variable "table_name" {
  description = "DynamoDB 表名，例如 edgeboard-dev"
  type        = string
}

variable "deletion_protection" {
  description = "是否开启删除保护（建议 prod 开启、dev 关闭）"
  type        = bool
  default     = true
}
