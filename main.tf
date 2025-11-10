# Main Terraform configuration for WebGL deployment
# This file orchestrates the S3, CloudFront, and IAM modules

# Terraform configuration is in versions.tf
# Optional: Configure backend for state management
# Uncomment and configure if you want to use remote state
# terraform {
#   backend "s3" {
#     bucket = "your-terraform-state-bucket"
#     key    = "webgl-deploy/${var.environment}/terraform.tfstate"
#     region = var.aws_region
#   }
# }

# Local value to determine if profile should be used
# In CI/CD, aws_profile is empty string, so we omit the profile attribute
locals {
  # Only use profile if it's not empty (for local deployments)
  # In CI/CD, credentials come from environment variables (AWS_ACCESS_KEY_ID, etc.)
  use_profile = var.aws_profile != "" && var.aws_profile != null
}

# Configure AWS provider
# Uses AWS_PROFILE environment variable set by deployment scripts
# Default profile name: deploy-config (can be overridden with AWS_PROFILE_NAME env var)
# In CI/CD (GitHub Actions), profile is empty and credentials come from OIDC
provider "aws" {
  region = var.aws_region
  # Conditionally set profile - only if use_profile is true
  # When false, Terraform will use credentials from environment variables
  profile = local.use_profile ? var.aws_profile : null

  # Optional: Set default tags for all resources
  default_tags {
    tags = var.common_tags
  }
}

# Random ID for bucket name uniqueness
# S3 bucket names must be globally unique
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Module: S3 Bucket
# Create S3 bucket first (CloudFront needs the bucket domain name)
# Note: Bucket policy will be created after CloudFront distribution is created
module "s3" {
  source = "./modules/s3"

  # Bucket configuration
  bucket_name                  = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  environment                  = var.environment
  cloudfront_distribution_arn  = module.cloudfront.distribution_arn

  # Bucket features
  enable_versioning   = var.enable_s3_versioning
  enable_cors         = var.enable_cors
  cors_allowed_origins = var.cors_allowed_origins
  enable_website_config = var.enable_website_config
  error_document       = var.error_document

  # Common tags
  common_tags = var.common_tags
}

# Module: CloudFront Distribution
# Create CloudFront distribution using S3 bucket as origin
# The S3 bucket policy will reference this distribution's ARN
module "cloudfront" {
  source = "./modules/cloudfront"

  # Distribution configuration
  distribution_name                = "${var.project_name}-${var.environment}"
  environment                     = var.environment
  s3_bucket_regional_domain_name  = module.s3.bucket_regional_domain_name
  distribution_comment             = "WebGL Build Distribution for ${var.environment}"
  default_root_object              = var.default_root_object
  enable_ipv6                      = var.enable_ipv6
  price_class                      = var.price_class

  # Cache configuration
  cache_policy_id = var.cache_policy_id
  min_ttl         = var.min_ttl
  default_ttl     = var.default_ttl
  max_ttl         = var.max_ttl

  # Custom error responses for SPA routing
  custom_error_responses = var.custom_error_responses

  # SSL/Certificate configuration
  acm_certificate_arn      = var.acm_certificate_arn
  minimum_protocol_version = var.minimum_protocol_version
  aliases                  = var.cloudfront_aliases

  # Geo restrictions
  geo_restriction_type     = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations

  # Common tags
  common_tags = var.common_tags
}

# Module: IAM (Optional)
# Create IAM roles and policies for deployment
module "iam" {
  source = "./modules/iam"
  count  = var.create_iam_resources ? 1 : 0

  # IAM configuration
  s3_bucket_arn              = module.s3.bucket_arn
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  environment                = var.environment
  policy_name_prefix         = "${var.project_name}-${var.environment}"
  role_name_prefix           = "${var.project_name}-${var.environment}"

  # IAM resource creation flags
  create_deployment_policy = var.create_deployment_policy
  create_deployment_role  = var.create_deployment_role
  assume_role_services    = var.assume_role_services
  github_actions_oidc     = var.github_actions_oidc

  # Common tags
  common_tags = var.common_tags
}

