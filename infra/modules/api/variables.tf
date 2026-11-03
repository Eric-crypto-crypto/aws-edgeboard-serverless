variable "name" {
  description = "API name, e.g. edgeboard-dev-api"
  type        = string
}

variable "routes" {
  description = "Route table: keys are route keys (e.g. \"POST /api/visit\"), values describe the target Lambda"
  type = map(object({
    function_name = string
    invoke_arn    = string
  }))
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second"
  type        = number
  default     = 20
}

variable "throttling_burst_limit" {
  description = "Maximum burst of requests"
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "Access log retention in days"
  type        = number
  default     = 14
}
