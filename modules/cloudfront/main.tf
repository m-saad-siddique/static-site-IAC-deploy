# CloudFront Module - Creates a CloudFront distribution for WebGL deployment
# Uses Origin Access Control (OAC) to securely access the private S3 bucket
# Note: Provider requirements are defined in the root module (versions.tf)

# Create Origin Access Control (OAC) for secure S3 access
# OAC is the modern replacement for OAI (Origin Access Identity)
# Name includes unique suffix to avoid conflicts with existing OACs
resource "aws_cloudfront_origin_access_control" "webgl_oac" {
  name                              = "${var.distribution_name}-oac-${var.unique_suffix}"
  description                       = "OAC for ${var.distribution_name} to access S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Create CloudFront distribution
resource "aws_cloudfront_distribution" "webgl_distribution" {
  # Distribution is enabled by default
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = var.distribution_comment
  default_root_object = var.default_root_object
  price_class         = var.price_class

  # Origin configuration - S3 bucket with OAC
  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = var.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.webgl_oac.id
  }

  # Default cache behavior
  default_cache_behavior {
    # Use the origin defined above
    target_origin_id = var.origin_id

    # Viewer protocol policy - redirect HTTP to HTTPS
    viewer_protocol_policy = "redirect-to-https"

    # Allowed HTTP methods
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    # Methods that can be cached
    cached_methods = ["GET", "HEAD"]

    # Use managed cache policy (CachingOptimized)
    # This provides optimized caching for static content
    cache_policy_id           = var.cache_policy_id
    origin_request_policy_id  = var.origin_request_policy_id

    # Compress objects automatically
    compress = true

    # Minimum TTL for cached content
    min_ttl     = var.min_ttl
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }

  # Custom error responses for SPA routing
  # Redirect 403 and 404 errors to index.html for client-side routing
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Viewer certificate configuration
  # Use ACM certificate if provided, otherwise use CloudFront default certificate
  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != "" ? var.minimum_protocol_version : null
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : false
  }

  # Restrict viewer access (optional - set to false for public access)
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # Aliases (custom domain names)
  aliases = var.aliases

  # Tags for resource management
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.distribution_name}-cloudfront"
      Environment = var.environment
      Purpose     = "WebGL Distribution"
    }
  )
}

