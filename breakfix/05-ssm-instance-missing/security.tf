resource "aws_security_group" "endpoints" {
  name        = "ssm-lab-endpoints-sg"
  description = "HTTPS from inside the VPC to the interface endpoints"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "ssm-lab-endpoints-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https_from_vpc" {
  security_group_id = aws_security_group.endpoints.id
  description       = "HTTPS from the VPC"
  cidr_ipv4         = aws_vpc.lab.cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_security_group" "batch" {
  name        = "ssm-lab-batch-sg"
  description = "Batch server: no inbound traffic, HTTPS to the VPC endpoints only"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "ssm-lab-batch-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "batch_https_to_vpc" {
  security_group_id = aws_security_group.batch.id
  description       = "HTTPS to the interface endpoints"
  cidr_ipv4         = aws_vpc.lab.cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
