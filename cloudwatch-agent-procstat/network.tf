data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "lab" {
  name        = "lab-cwagent-sg"
  description = "No inbound rules - access via SSM only"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.lab.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}