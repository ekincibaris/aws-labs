output "instance_id" {
  description = "ID of the orders-cache instance"
  value       = aws_instance.cache.id
}

output "alarm_name" {
  description = "Name of the memory alarm"
  value       = aws_cloudwatch_metric_alarm.memory_high.alarm_name
}
