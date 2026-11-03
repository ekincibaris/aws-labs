resource "aws_security_group" "bastion" {
  name        = "config-lab-bastion-sg"
  description = "Bastion host access"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "config-lab-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_anywhere" {
  security_group_id = aws_security_group.bastion.id
  description       = "TEMPORARY: SSH from anywhere for vendor debugging"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}
