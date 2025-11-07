# Outputs for CloudFront module

# CloudFront distribution ID
output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.webgl_distribution.id
}

# CloudFront distribution ARN
output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.webgl_distribution.arn
}

# CloudFront distribution domain name
output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.webgl_distribution.domain_name
}

# CloudFront distribution hosted zone ID
output "distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.webgl_distribution.hosted_zone_id
}

# Origin Access Control ID
output "oac_id" {
  description = "ID of the Origin Access Control"
  value       = aws_cloudfront_origin_access_control.webgl_oac.id
}

