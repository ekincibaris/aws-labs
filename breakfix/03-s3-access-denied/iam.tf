resource "aws_iam_role" "reports_app" {
  name = "s3-lab-reports-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "reports_app_logs" {
  role       = aws_iam_role.reports_app.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "reports_bucket_access" {
  name = "reports-bucket-access"
  role = aws_iam_role.reports_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListReports"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.reports.arn
      },
      {
        Sid      = "ReadWriteReports"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.reports.arn}/reports/*"
      },
      {
        Sid      = "UseReportsKey"
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.reports.arn
      },
    ]
  })
}
