output "function_name" {
  description = "Name of the partner-sync Lambda function"
  value       = aws_lambda_function.partner_sync.function_name
}

output "nat_public_ip" {
  description = "Elastic IP address of the NAT gateway"
  value       = aws_eip.nat.public_ip
}
