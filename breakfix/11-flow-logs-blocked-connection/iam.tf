resource "aws_iam_role" "server" {
  name = "flowlogs-lab-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Session Manager access. The managed policy also allows reading SSM parameters,
# which the stock report uses to look up the inventory-api URL.
resource "aws_iam_role_policy_attachment" "server_ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "server" {
  name = "flowlogs-lab-server-profile"
  role = aws_iam_role.server.name
}
