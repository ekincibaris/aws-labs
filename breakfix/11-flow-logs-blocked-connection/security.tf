resource "aws_security_group" "reporting" {
  name        = "flowlogs-lab-reporting-sg"
  description = "Reporting server: no inbound traffic, all outbound"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "flowlogs-lab-reporting-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "reporting_all_out" {
  security_group_id = aws_security_group.reporting.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "inventory" {
  name        = "flowlogs-lab-inventory-sg"
  description = "inventory-api: port 8080 for the reporting servers only"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "flowlogs-lab-inventory-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "inventory_api_from_reporting" {
  security_group_id            = aws_security_group.inventory.id
  description                  = "inventory-api from the reporting servers"
  referenced_security_group_id = aws_security_group.reporting.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "inventory_all_out" {
  security_group_id = aws_security_group.inventory.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
