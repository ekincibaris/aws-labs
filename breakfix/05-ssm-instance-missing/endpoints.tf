locals {
  # Endpoints that SSM Agent and Session Manager need without internet access.
  ssm_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(local.ssm_services)

  vpc_id              = aws_vpc.lab.id
  service_name        = "com.amazonaws.eu-central-1.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = false

  tags = {
    Name = "ssm-lab-${each.key}"
  }
}
