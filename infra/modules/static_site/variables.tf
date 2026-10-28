variable "name" {
  description = "资源名前缀，例如 edgeboard-dev"
  type        = string
}

variable "force_destroy" {
  description = "destroy 时是否允许删除非空的桶（建议 dev 开启、prod 关闭）"
  type        = bool
  default     = false
}
