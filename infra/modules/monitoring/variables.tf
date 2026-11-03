variable "name" {
  description = "Resource name prefix, e.g. edgeboard-dev"
  type        = string
}

variable "alert_email" {
  description = "Email address that receives alarm notifications"
  type        = string
  sensitive   = true
}

variable "lambda_functions" {
  description = "Lambda functions to monitor: short name => function name"
  type        = map(string)
}

variable "api_id" {
  description = "ID of the HTTP API"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}
