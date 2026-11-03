output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.lab.name
}

output "service_name" {
  description = "Name of the orders-api ECS service"
  value       = aws_ecs_service.api.name
}

output "log_group_name" {
  description = "CloudWatch Logs group for the orders-api containers"
  value       = aws_cloudwatch_log_group.api.name
}
