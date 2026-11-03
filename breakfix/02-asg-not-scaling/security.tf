resource "aws_security_group" "worker" {
  name        = "asg-lab-worker-sg"
  description = "Transcoding workers: no inbound traffic, all outbound"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "asg-lab-worker-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "worker_all_out" {
  security_group_id = aws_security_group.worker.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
