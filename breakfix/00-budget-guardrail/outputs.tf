output "budget_name" {
  description = "Name of the monthly cost budget"
  value       = aws_budgets_budget.monthly.name
}

output "monthly_limit_usd" {
  description = "Monthly limit in USD after converting from EUR"
  value       = local.monthly_limit_usd
}

output "billing_alarm_arn" {
  description = "ARN of the CloudWatch billing alarm"
  value       = aws_cloudwatch_metric_alarm.estimated_charges.arn
}
