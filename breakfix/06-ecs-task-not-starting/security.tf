resource "aws_security_group" "api" {
  name        = "ecs-lab-orders-api-sg"
  description = "orders-api tasks: no inbound traffic, all outbound (image pulls, logs, Parameter Store)"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "ecs-lab-orders-api-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "api_all_out" {
  security_group_id = aws_security_group.api.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
