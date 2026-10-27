resource "aws_key_pair" "lab" {
  key_name   = "nacl-lab"
  public_key = file(pathexpand("~/.ssh/nacl-lab.pub"))
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
resource "aws_instance" "lab" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.lab.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "nacl-lab-ec2"
  }
}

output "public_ip" {
  value = aws_instance.lab.public_ip
}