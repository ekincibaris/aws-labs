output "bucket_name" {
  description = "Name of the reports bucket"
  value       = aws_s3_bucket.reports.id
}

output "exporter_function" {
  description = "Lambda function that writes this month's report"
  value       = aws_lambda_function.function["exporter"].function_name
}

output "viewer_function" {
  description = "Lambda function that reads a report"
  value       = aws_lambda_function.function["viewer"].function_name
}
