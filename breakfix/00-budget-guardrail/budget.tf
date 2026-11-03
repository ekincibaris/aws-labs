locals {
  monthly_limit_usd = format("%.2f", var.monthly_limit_eur * var.usd_per_eur)
}

resource "aws_budgets_budget" "monthly" {
  name         = "budget-lab-monthly-guardrail"
  budget_type  = "COST"
  limit_amount = local.monthly_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Early warning: half of the monthly limit has been spent.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Fires before the money is spent if the current rate would exceed the limit.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
