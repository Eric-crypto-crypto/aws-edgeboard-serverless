variable "alert_email" {
  description = "告警通知邮箱。通过环境变量 TF_VAR_alert_email 传入，不要写进代码"
  type        = string
  sensitive   = true
}
