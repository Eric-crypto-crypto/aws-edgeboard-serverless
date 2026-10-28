variable "name" {
  description = "API 名称，例如 edgeboard-dev-api"
  type        = string
}

variable "routes" {
  description = "路由表：键为路由（如 \"POST /api/visit\"），值为对应的 Lambda 信息"
  type = map(object({
    function_name = string
    invoke_arn    = string
  }))
}

variable "throttling_rate_limit" {
  description = "稳定状态下每秒允许的请求数"
  type        = number
  default     = 20
}

variable "throttling_burst_limit" {
  description = "允许瞬时涌入的请求上限"
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "访问日志保留天数"
  type        = number
  default     = 14
}
