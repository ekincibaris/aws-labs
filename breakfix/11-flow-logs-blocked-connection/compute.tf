data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "inventory" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.lab["inventory"].id
  vpc_security_group_ids      = [aws_security_group.inventory.id]
  iam_instance_profile        = aws_iam_instance_profile.server.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user-data-inventory.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "flowlogs-lab-inventory-api"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_instance" "reporting" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = "t4g.micro"
  subnet_id                   = aws_subnet.lab["reporting"].id
  vpc_security_group_ids      = [aws_security_group.reporting.id]
  iam_instance_profile        = aws_iam_instance_profile.server.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user-data-reporting.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "flowlogs-lab-reporting-01"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Where the stock report finds inventory-api. Updated by the inventory team on every redeploy.
resource "aws_ssm_parameter" "inventory_url" {
  name        = "/flowlogs-lab/inventory-url"
  description = "URL of the inventory-api stock endpoint"
  type        = "String"
  value       = "http://${aws_instance.inventory.public_ip}:8080/stock.json"
}
