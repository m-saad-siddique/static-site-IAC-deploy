# Outputs for WebGL deployment

# S3 Bucket outputs
output "s3_bucket_id" {
  description = "ID of the S3 bucket"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = module.s3.bucket_domain_name
}

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution (use this URL to access your WebGL build)"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution (for DNS configuration)"
  value       = module.cloudfront.distribution_hosted_zone_id
}

# IAM outputs (if created)
output "deployment_policy_arn" {
  description = "ARN of the deployment IAM policy"
  value       = var.create_iam_resources ? module.iam[0].deployment_policy_arn : null
}

output "deployment_role_arn" {
  description = "ARN of the deployment IAM role"
  value       = var.create_iam_resources && var.create_deployment_role ? module.iam[0].deployment_role_arn : null
}

# Deployment URL
output "deployment_url" {
  description = "URL to access the deployed WebGL build"
  value       = "https://${module.cloudfront.distribution_domain_name}"
}

