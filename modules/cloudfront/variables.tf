# Variables for CloudFront module

# Distribution name
variable "distribution_name" {
  description = "Name of the CloudFront distribution"
  type        = string
}

# Environment name
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# S3 bucket regional domain name (for origin)
variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  type        = string
}

# Origin ID
variable "origin_id" {
  description = "Origin ID for the CloudFront distribution"
  type        = string
  default     = "S3-WebGL-Origin"
}

# Distribution comment
variable "distribution_comment" {
  description = "Comment for the CloudFront distribution"
  type        = string
  default     = "WebGL Build Distribution"
}

# Default root object
variable "default_root_object" {
  description = "Default root object (e.g., index.html)"
  type        = string
  default     = "index.html"
}

# Enable IPv6
variable "enable_ipv6" {
  description = "Enable IPv6 for the distribution"
  type        = bool
  default     = true
}

# Price class
variable "price_class" {
  description = "Price class for CloudFront (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

# Cache policy ID (use managed policy or custom)
variable "cache_policy_id" {
  description = "Cache policy ID (use managed policy ID or custom)"
  type        = string
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
}

variable "origin_request_policy_id" {
  description = "Origin request policy ID (optional). Set to null to omit."
  type        = string
  default     = null
}

# TTL values for caching
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

# ACM certificate ARN (optional - for custom domain)
variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

# Minimum protocol version
variable "minimum_protocol_version" {
  description = "Minimum TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}

# Aliases (custom domain names)
variable "aliases" {
  description = "List of aliases (custom domain names) for the distribution"
  type        = list(string)
  default     = []
}

# Geo restriction
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

# Common tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

