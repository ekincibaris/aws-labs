resource "aws_iam_role" "batch" {
  name = "ssm-lab-batch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_ssm" {
  role       = aws_iam_role.batch.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "batch" {
  name = "ssm-lab-batch-profile"
  role = aws_iam_role.batch.name
}
