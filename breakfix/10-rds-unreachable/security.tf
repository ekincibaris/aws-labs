resource "aws_security_group" "app" {
  name        = "rds-lab-app-sg"
  description = "orders-app server: no inbound traffic, all outbound"
  vpc_id      = aws_vpc.app.id

  tags = {
    Name = "rds-lab-app-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db" {
  name        = "rds-lab-db-sg"
  description = "orders database: PostgreSQL from the application VPC"
  vpc_id      = aws_vpc.data.id

  tags = {
    Name = "rds-lab-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_postgres_from_app_vpc" {
  security_group_id = aws_security_group.db.id
  description       = "PostgreSQL from the application VPC"
  cidr_ipv4         = aws_vpc.app.cidr_block
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}
