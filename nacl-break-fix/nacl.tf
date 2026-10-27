resource "aws_network_acl" "lab" {
  vpc_id     = aws_vpc.lab.id
  subnet_ids = [aws_subnet.public.id]

  tags = {
    Name = "nacl-lab-custom"
  }
}

resource "aws_network_acl_rule" "ssh_inbound" {
  network_acl_id = aws_network_acl.lab.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.my_ip_cidr
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "ssh_outbound" {
  network_acl_id = aws_network_acl.lab.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.my_ip_cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "dnf_inbound" {
  network_acl_id = aws_network_acl.lab.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "dnf_outbound" {
  network_acl_id = aws_network_acl.lab.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}