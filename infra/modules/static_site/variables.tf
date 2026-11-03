variable "name" {
  description = "Resource name prefix, e.g. edgeboard-dev"
  type        = string
}

variable "force_destroy" {
  description = "Allow destroying a non-empty bucket (recommended on in dev, off in prod)"
  type        = bool
  default     = false
}

variable "api_domain" {
  description = "API Gateway domain without https://, e.g. abc123.execute-api.ap-southeast-2.amazonaws.com"
  type        = string
}

variable "domain_name" {
  description = "Site domain, e.g. dev.example.com"
  type        = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}
