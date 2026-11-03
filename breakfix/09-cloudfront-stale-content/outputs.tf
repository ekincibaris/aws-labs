output "site_url" {
  description = "Public URL of the site (through CloudFront)"
  value       = "https://${aws_cloudfront_distribution.site.domain_name}/"
}

output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.site.id
}

output "bucket_name" {
  description = "Name of the S3 bucket behind the distribution"
  value       = aws_s3_bucket.site.id
}
