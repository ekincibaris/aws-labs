variable "alert_email" {
  description = "Optional email address subscribed to the alarm's SNS topic. Leave null to watch the alarm in the console only."
  type        = string
  default     = null
}
