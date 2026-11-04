resource "aws_security_group" "cache" {
  name        = "alarm-lab-cache-sg"
  description = "orders-cache: no inbound traffic, all outbound"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "alarm-lab-cache-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "cache_all_out" {
  security_group_id = aws_security_group.cache.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
