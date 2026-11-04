output "bucket_name" {
  description = "Name of the invoices bucket"
  value       = aws_s3_bucket.invoices.id
}

output "rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.invoice_uploaded.name
}

output "function_name" {
  description = "Name of the invoice-ingest Lambda function"
  value       = aws_lambda_function.invoice_ingest.function_name
}
