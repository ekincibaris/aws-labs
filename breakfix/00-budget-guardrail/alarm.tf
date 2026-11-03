resource "aws_sns_topic" "billing_alerts" {
  name = "budget-lab-billing-alerts"
}

resource "aws_sns_topic_subscription" "billing_email" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  alarm_name        = "budget-lab-estimated-charges"
  alarm_description = "Estimated charges for this month passed ${var.monthly_limit_eur} EUR (${local.monthly_limit_usd} USD)."

  namespace   = "AWS/Billing"
  metric_name = "EstimatedCharges"
  dimensions = {
    Currency = "USD"
  }

  statistic           = "Maximum"
  period              = 21600
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = tonumber(local.monthly_limit_usd)

  alarm_actions = [aws_sns_topic.billing_alerts.arn]
  ok_actions    = [aws_sns_topic.billing_alerts.arn]
}
