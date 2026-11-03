variable "function_name" {
  description = "Lambda function name, e.g. edgeboard-dev-visit"
  type        = string
}

variable "handler" {
  description = "Entry point as <module path>.<function>, e.g. handlers.visit.handler"
  type        = string
}

variable "filename" {
  description = "Local path to the code zip"
  type        = string
}

variable "source_code_hash" {
  description = "Hash of the code zip; a change triggers redeployment"
  type        = string
}

variable "environment" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "layers" {
  description = "List of Lambda layer ARNs"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table the function may access"
  type        = string
}

variable "dynamodb_actions" {
  description = "DynamoDB actions to allow (least privilege), e.g. [\"dynamodb:Query\"]"
  type        = list(string)
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 5
}

variable "memory_size" {
  description = "Memory in MB; CPU scales with memory"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 14
}
