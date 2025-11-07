# Root variables for WebGL deployment

# Project name
variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "webgl"
}

# Environment name
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

# AWS region
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# AWS profile
variable "aws_profile" {
  description = "AWS profile to use for authentication (defaults to deploy-config)"
  type        = string
  default     = "deploy-config"
}

# Common tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "WebGL Deployment"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

# CloudFront Configuration
variable "default_root_object" {
  description = "Default root object for CloudFront (e.g., index.html)"
  type        = string
  default     = "index.html"
}

variable "enable_ipv6" {
  description = "Enable IPv6 for CloudFront distribution"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "Price class for CloudFront (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "cache_policy_id" {
  description = "Cache policy ID for CloudFront (use managed policy ID)"
  type        = string
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
}

variable "min_ttl" {
  description = "Minimum TTL for cached content (seconds)"
  type        = number
  default     = 0
}

variable "default_ttl" {
  description = "Default TTL for cached content (seconds)"
  type        = number
  default     = 86400 # 1 day
}

variable "max_ttl" {
  description = "Maximum TTL for cached content (seconds)"
  type        = number
  default     = 31536000 # 1 year
}

# Custom error responses for SPA routing
variable "custom_error_responses" {
  description = "List of custom error responses"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    },
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    }
  ]
}

# SSL/Certificate configuration
variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain (must be in us-east-1). Leave empty to use CloudFront default certificate"
  type        = string
  default     = ""
}

variable "minimum_protocol_version" {
  description = "Minimum TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "cloudfront_aliases" {
  description = "List of aliases (custom domain names) for CloudFront"
  type        = list(string)
  default     = []
}

# Geo restrictions
variable "geo_restriction_type" {
  description = "Geo restriction type (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

# S3 Configuration
variable "enable_s3_versioning" {
  description = "Enable versioning on S3 bucket"
  type        = bool
  default     = false
}

variable "enable_cors" {
  description = "Enable CORS on S3 bucket"
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "enable_website_config" {
  description = "Enable website configuration on S3 bucket"
  type        = bool
  default     = false
}

variable "error_document" {
  description = "Error document for S3 website configuration"
  type        = string
  default     = "index.html"
}

# IAM Configuration
variable "create_iam_resources" {
  description = "Whether to create IAM resources (policies and roles)"
  type        = bool
  default     = false
}

variable "create_deployment_policy" {
  description = "Whether to create the deployment IAM policy"
  type        = bool
  default     = true
}

variable "create_deployment_role" {
  description = "Whether to create the deployment IAM role"
  type        = bool
  default     = false
}

variable "assume_role_services" {
  description = "List of AWS services that can assume the deployment role (e.g., ['ec2.amazonaws.com']). Leave empty if using GitHub Actions OIDC."
  type        = list(string)
  default     = []
}

variable "github_actions_oidc" {
  description = "GitHub Actions OIDC configuration. Set to null to disable. Format: { account_id = '123456789', repository_filter = 'repo:owner/repo:*' }"
  type = object({
    account_id        = string
    repository_filter = string
  })
  default = null
}

