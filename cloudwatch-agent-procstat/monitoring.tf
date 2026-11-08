resource "aws_sns_topic" "alerts" {
  name = "lab-cwagent-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "nginx_down" {
  alarm_name        = "lab-nginx-down"
  alarm_description = "nginx process is not running"

  namespace   = "CWAgent"
  metric_name = "procstat_lookup_pid_count"
  dimensions = {
    InstanceId = aws_instance.lab.id
    exe        = "nginx"
    pid_finder = "native"
  }

  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}