output "app_instance_id" {
  description = "ID of the orders-app server"
  value       = aws_instance.app.id
}

output "db_endpoint" {
  description = "Hostname of the orders database"
  value       = aws_db_instance.orders.address
}

output "peering_connection_id" {
  description = "ID of the VPC peering connection between the app and data VPCs"
  value       = aws_vpc_peering_connection.app_to_data.id
}
