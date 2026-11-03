resource "aws_vpc_peering_connection" "app_to_data" {
  vpc_id      = aws_vpc.app.id
  peer_vpc_id = aws_vpc.data.id
  auto_accept = true

  tags = {
    Name = "rds-lab-app-to-data"
  }
}

resource "aws_route" "app_to_data" {
  route_table_id            = aws_route_table.app.id
  destination_cidr_block    = aws_vpc.data.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_data.id
}
