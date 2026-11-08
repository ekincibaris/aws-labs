data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "lab" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  iam_instance_profile        = aws_iam_instance_profile.ec2_agent.name
  vpc_security_group_ids      = [aws_security_group.lab.id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx amazon-cloudwatch-agent
    systemctl enable --now nginx
  EOF

  tags = {
    Name = "lab-cwagent"
  }
}

output "instance_id" {
  value = aws_instance.lab.id
}