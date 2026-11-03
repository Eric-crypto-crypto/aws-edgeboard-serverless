variable "table_name" {
  description = "DynamoDB table name, e.g. edgeboard-dev"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection (recommended on in prod, off in dev)"
  type        = bool
  default     = true
}
