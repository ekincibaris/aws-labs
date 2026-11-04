output "shop_url" {
  description = "Public URL of the shop (through the load balancer)"
  value       = "http://${aws_lb.web.dns_name}"
}

output "target_group_arn" {
  description = "ARN of the target group behind the listener"
  value       = aws_lb_target_group.web.arn
}

output "web_instance_ids" {
  description = "IDs of the two web servers"
  value       = { for key, instance in aws_instance.web : key => instance.id }
}
