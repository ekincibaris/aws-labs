data "aws_caller_identity" "current" {}

resource "aws_kms_key" "reports" {
  description             = "Encrypts the monthly reports bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # The default key policy: the account owns the key, and IAM policies decide
  # who in the account may use it.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableIamPolicies"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_kms_alias" "reports" {
  name          = "alias/s3-lab-reports"
  target_key_id = aws_kms_key.reports.key_id
}
