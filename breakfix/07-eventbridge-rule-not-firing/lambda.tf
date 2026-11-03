resource "aws_iam_role" "invoice_ingest" {
  name = "events-lab-invoice-ingest-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "invoice_ingest_logs" {
  role       = aws_iam_role.invoice_ingest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "invoice_ingest" {
  type        = "zip"
  source_file = "${path.module}/src/invoice_ingest.py"
  output_path = "${path.module}/build/invoice_ingest.zip"
}

resource "aws_cloudwatch_log_group" "invoice_ingest" {
  name              = "/aws/lambda/events-lab-invoice-ingest"
  retention_in_days = 1
}

resource "aws_lambda_function" "invoice_ingest" {
  function_name    = "events-lab-invoice-ingest"
  role             = aws_iam_role.invoice_ingest.arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  handler          = "invoice_ingest.handler"
  filename         = data.archive_file.invoice_ingest.output_path
  source_code_hash = data.archive_file.invoice_ingest.output_base64sha256
  timeout          = 10
  memory_size      = 128

  depends_on = [
    aws_cloudwatch_log_group.invoice_ingest,
    aws_iam_role_policy_attachment.invoice_ingest_logs,
  ]
}
