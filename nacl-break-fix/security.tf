resource "aws_security_group" "lab" {
  name        = "nacl-lab-sg"
  description = "SSH from my IP, all outbound"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "nacl-lab-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_me" {
  security_group_id = aws_security_group.lab.id
  description       = "SSH from my public IP"
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.lab.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
