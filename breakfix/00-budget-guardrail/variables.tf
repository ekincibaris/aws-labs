variable "alert_email" {
  description = "Email address that receives the budget and billing alerts"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "monthly_limit_eur" {
  description = "Monthly spending limit in EUR"
  type        = number
  default     = 5
}

variable "usd_per_eur" {
  description = "Exchange rate used to convert the EUR limit to USD. AWS Budgets and billing metrics only work in USD. A slightly low rate makes the alerts fire a little early, which is the safe side."
  type        = number
  default     = 1.10
}
