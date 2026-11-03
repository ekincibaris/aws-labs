data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "cache" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.cache.id]
  iam_instance_profile        = aws_iam_instance_profile.cache.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user-data.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "alarm-lab-orders-cache"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
