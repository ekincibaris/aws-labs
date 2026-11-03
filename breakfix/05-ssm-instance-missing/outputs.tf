output "instance_id" {
  description = "ID of the batch server that should be managed by Systems Manager"
  value       = aws_instance.batch.id
}

output "vpc_endpoint_ids" {
  description = "IDs of the Systems Manager interface endpoints"
  value       = { for service, endpoint in aws_vpc_endpoint.ssm : service => endpoint.id }
}
