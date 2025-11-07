# Variables for IAM module

# S3 bucket ARN
variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

# CloudFront distribution ARN
variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  type        = string
}

# Environment name
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# Policy name prefix
variable "policy_name_prefix" {
  description = "Prefix for IAM policy names"
  type        = string
  default     = "webgl"
}

# Role name prefix
variable "role_name_prefix" {
  description = "Prefix for IAM role names"
  type        = string
  default     = "webgl"
}

# Create deployment policy
variable "create_deployment_policy" {
  description = "Whether to create the deployment IAM policy"
  type        = bool
  default     = true
}

# Create deployment role
variable "create_deployment_role" {
  description = "Whether to create the deployment IAM role"
  type        = bool
  default     = false
}

# Services that can assume the role
variable "assume_role_services" {
  description = "List of AWS services that can assume the role (e.g., ['ec2.amazonaws.com'])"
  type        = list(string)
  default     = []
}

# GitHub Actions OIDC configuration
variable "github_actions_oidc" {
  description = "GitHub Actions OIDC configuration. Set to null to disable. Format: { account_id = '123456789', repository_filter = 'repo:owner/repo:*' }"
  type = object({
    account_id        = string
    repository_filter = string
  })
  default = null
}

# Common tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

