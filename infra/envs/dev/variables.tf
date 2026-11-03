variable "alert_email" {
  description = "Email address for alarm notifications. Pass it via TF_VAR_alert_email; never commit it"
  type        = string
  sensitive   = true
}
