# AWS Config recorder and delivery channel. Only one recorder is allowed per
# account and Region, so this is optional (var.create_config_recorder).

locals {
  recorder_count = var.create_config_recorder ? 1 : 0
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "config" {
  count = local.recorder_count

  bucket_prefix = "config-lab-delivery-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  count = local.recorder_count

  bucket                  = aws_s3_bucket.config[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config" {
  count = local.recorder_count

  bucket = aws_s3_bucket.config[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ConfigBucketCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.config[0].arn
        Condition = { StringEquals = { "AWS:SourceAccount" = data.aws_caller_identity.current.account_id } }
      },
      {
        Sid       = "ConfigDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.config]
}

resource "aws_iam_role" "config_recorder" {
  count = local.recorder_count

  name = "config-lab-recorder-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_recorder" {
  count = local.recorder_count

  role       = aws_iam_role.config_recorder[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_delivery" {
  count = local.recorder_count

  name = "deliver-to-config-bucket"
  role = aws_iam_role.config_recorder[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
      },
    ]
  })
}

resource "aws_config_configuration_recorder" "lab" {
  count = local.recorder_count

  name     = "config-lab-recorder"
  role_arn = aws_iam_role.config_recorder[0].arn

  # Record security groups only, which keeps the lab's Config bill to a few cents.
  recording_group {
    all_supported  = false
    resource_types = ["AWS::EC2::SecurityGroup"]

    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }
}

resource "aws_config_delivery_channel" "lab" {
  count = local.recorder_count

  name           = "config-lab-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].id

  depends_on = [
    aws_config_configuration_recorder.lab,
    aws_s3_bucket_policy.config,
  ]
}

resource "aws_config_configuration_recorder_status" "lab" {
  count = local.recorder_count

  name       = aws_config_configuration_recorder.lab[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.lab]
}
