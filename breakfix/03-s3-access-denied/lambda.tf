locals {
  functions = {
    exporter = "s3-lab-report-exporter"
    viewer   = "s3-lab-report-viewer"
  }
}

data "archive_file" "function" {
  for_each = local.functions

  type        = "zip"
  source_file = "${path.module}/src/${each.key}.py"
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "aws_cloudwatch_log_group" "function" {
  for_each = local.functions

  name              = "/aws/lambda/${each.value}"
  retention_in_days = 1
}

resource "aws_lambda_function" "function" {
  for_each = local.functions

  function_name    = each.value
  role             = aws_iam_role.reports_app.arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  handler          = "${each.key}.handler"
  filename         = data.archive_file.function[each.key].output_path
  source_code_hash = data.archive_file.function[each.key].output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      REPORTS_BUCKET = aws_s3_bucket.reports.id
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.function,
    aws_iam_role_policy_attachment.reports_app_logs,
  ]
}
