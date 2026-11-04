resource "aws_cloudwatch_event_rule" "invoice_uploaded" {
  name        = "events-lab-invoice-uploaded"
  description = "A new invoice was uploaded to incoming/ in the invoices bucket"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [aws_s3_bucket.invoices.id] }
      object = { key = [{ prefix = "incoming/" }] }
    }
  })
}

resource "aws_cloudwatch_event_target" "invoice_ingest" {
  rule      = aws_cloudwatch_event_rule.invoice_uploaded.name
  target_id = "invoice-ingest"
  arn       = aws_lambda_function.invoice_ingest.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowInvoiceUploadedRule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.invoice_ingest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.invoice_uploaded.arn
}
