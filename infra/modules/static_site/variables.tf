variable "name" {
  description = "资源名前缀，例如 edgeboard-dev"
  type        = string
}

variable "force_destroy" {
  description = "destroy 时是否允许删除非空的桶（建议 dev 开启、prod 关闭）"
  type        = bool
  default     = false
}

variable "api_domain" {
  description = "API Gateway 的域名（不带 https://），例如 abc123.execute-api.ap-southeast-2.amazonaws.com"
  type        = string
}
