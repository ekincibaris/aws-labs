resource "aws_sns_topic" "alerts" {
  name = "alarm-lab-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name        = "alarm-lab-orders-cache-memory-high"
  alarm_description = "orders-cache uses more than 60 % of its memory. Page the on-call engineer."

  namespace   = "CWAgent"
  metric_name = "mem_used_percent"
  dimensions = {
    InstanceId = aws_instance.cache.id
  }

  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 60
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
