# Outputs for S3 module

# S3 bucket ID
output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.webgl_bucket.id
}

# S3 bucket ARN
output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.webgl_bucket.arn
}

# S3 bucket domain name
output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.webgl_bucket.bucket_domain_name
}

# S3 bucket regional domain name
output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket (for CloudFront origin)"
  value       = aws_s3_bucket.webgl_bucket.bucket_regional_domain_name
}

