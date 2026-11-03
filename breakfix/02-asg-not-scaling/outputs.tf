output "autoscaling_group_name" {
  description = "Name of the worker Auto Scaling group"
  value       = aws_autoscaling_group.workers.name
}

output "scaling_policy_name" {
  description = "Name of the target tracking scaling policy"
  value       = aws_autoscaling_policy.cpu_target.name
}
