data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# Amazon Linux 2023 ships with SSM Agent installed and enabled.
resource "aws_instance" "batch" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.batch.id]
  iam_instance_profile        = aws_iam_instance_profile.batch.name
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "ssm-lab-batch"
  }

  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [aws_vpc_endpoint.ssm]
}
