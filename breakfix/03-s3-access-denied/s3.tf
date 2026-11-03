resource "aws_s3_bucket" "reports" {
  bucket_prefix = "s3-lab-reports-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.reports.arn
    }
  }
}

resource "aws_s3_bucket_policy" "reports" {
  bucket = aws_s3_bucket.reports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.reports.arn, "${aws_s3_bucket.reports.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.reports]
}

# Last month's report, uploaded by the finance team.
resource "aws_s3_object" "october_report" {
  bucket       = aws_s3_bucket.reports.id
  key          = "reports/2026-10.csv"
  content      = "month,orders,revenue_eur\n2026-10,1284,48210.50\n"
  content_type = "text/csv"

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.reports]
}
