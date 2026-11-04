resource "aws_iam_role" "partner_sync" {
  name = "lambda-lab-partner-sync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Logs plus the EC2 permissions Lambda needs to manage its VPC network interfaces.
resource "aws_iam_role_policy_attachment" "partner_sync_vpc" {
  role       = aws_iam_role.partner_sync.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "partner_sync" {
  type        = "zip"
  source_file = "${path.module}/src/partner_sync.py"
  output_path = "${path.module}/build/partner_sync.zip"
}

resource "aws_cloudwatch_log_group" "partner_sync" {
  name              = "/aws/lambda/lambda-lab-partner-sync"
  retention_in_days = 1
}

resource "aws_lambda_function" "partner_sync" {
  function_name    = "lambda-lab-partner-sync"
  role             = aws_iam_role.partner_sync.arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  handler          = "partner_sync.handler"
  filename         = data.archive_file.partner_sync.output_path
  source_code_hash = data.archive_file.partner_sync.output_base64sha256
  timeout          = 10
  memory_size      = 128

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.public : subnet.id]
    security_group_ids = [aws_security_group.partner_sync.id]
  }

  depends_on = [
    aws_cloudwatch_log_group.partner_sync,
    aws_iam_role_policy_attachment.partner_sync_vpc,
  ]
}
