data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "web" {
  for_each = aws_subnet.public

  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = "t4g.micro"
  subnet_id                   = each.value.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.web.name
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
    Name = "alb-lab-web-${each.key}"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
