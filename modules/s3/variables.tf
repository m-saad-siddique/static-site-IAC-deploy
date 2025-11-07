# Variables for S3 module

# Bucket name (should be unique globally)
variable "bucket_name" {
  description = "Name of the S3 bucket for WebGL deployment"
  type        = string
}

# Environment name (dev, staging, prod)
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# CloudFront distribution ARN (required for bucket policy)
variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution that will access this bucket"
  type        = string
}

# Common tags to apply to all resources
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Enable versioning on the bucket
variable "enable_versioning" {
  description = "Enable versioning on the S3 bucket"
  type        = bool
  default     = false
}

# Enable CORS configuration
variable "enable_cors" {
  description = "Enable CORS configuration for the bucket"
  type        = bool
  default     = true
}

# CORS allowed origins
variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

# Enable website configuration
variable "enable_website_config" {
  description = "Enable website configuration for the bucket"
  type        = bool
  default     = false
}

# Error document for website configuration
variable "error_document" {
  description = "Error document key for website configuration"
  type        = string
  default     = "index.html"
}

