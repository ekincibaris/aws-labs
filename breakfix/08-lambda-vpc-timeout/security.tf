resource "aws_security_group" "partner_sync" {
  name        = "lambda-lab-partner-sync-sg"
  description = "partner-sync function: no inbound traffic, all outbound"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "lambda-lab-partner-sync-sg"
  }

  timeouts {
    delete = "45m"
  }
}

resource "aws_vpc_security_group_egress_rule" "partner_sync_all_out" {
  security_group_id = aws_security_group.partner_sync.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
