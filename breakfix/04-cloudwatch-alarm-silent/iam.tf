resource "aws_iam_role" "cache" {
  name = "alarm-lab-cache-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cache_ssm" {
  role       = aws_iam_role.cache.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cache_cloudwatch_agent" {
  role       = aws_iam_role.cache.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cache" {
  name = "alarm-lab-cache-profile"
  role = aws_iam_role.cache.name
}
