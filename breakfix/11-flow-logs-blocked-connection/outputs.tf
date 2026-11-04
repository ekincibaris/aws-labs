output "reporting_instance_id" {
  description = "ID of reporting-01"
  value       = aws_instance.reporting.id
}

output "inventory_instance_id" {
  description = "ID of inventory-api"
  value       = aws_instance.inventory.id
}

output "flow_log_group" {
  description = "CloudWatch Logs group that receives the VPC flow logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
