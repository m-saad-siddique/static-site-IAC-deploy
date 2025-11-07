# S3 Module - Creates a private S3 bucket for WebGL deployment
# This bucket will only be accessible via CloudFront using Origin Access Control (OAC)
# Note: Provider requirements are defined in the root module (versions.tf)

# Create the S3 bucket for storing WebGL build files
resource "aws_s3_bucket" "webgl_bucket" {
  # Bucket name with environment prefix
  bucket = var.bucket_name

  # Tags for resource management
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.bucket_name}-webgl"
      Environment = var.environment
      Purpose     = "WebGL Static Assets"
    }
  )
}

# Block all public access to the bucket
# This ensures the bucket is private and only accessible via CloudFront
resource "aws_s3_bucket_public_access_block" "webgl_bucket_pab" {
  bucket = aws_s3_bucket.webgl_bucket.id

  # Block all public access settings
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for the bucket (optional but recommended)
resource "aws_s3_bucket_versioning" "webgl_bucket_versioning" {
  bucket = aws_s3_bucket.webgl_bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Enable server-side encryption for the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "webgl_bucket_encryption" {
  bucket = aws_s3_bucket.webgl_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      # Use AES256 encryption (free, managed by AWS)
      sse_algorithm = "AES256"
    }
  }
}

# Configure CORS if needed for WebGL applications
resource "aws_s3_bucket_cors_configuration" "webgl_bucket_cors" {
  count = var.enable_cors ? 1 : 0

  bucket = aws_s3_bucket.webgl_bucket.id

  cors_rule {
    # Allow all origins (adjust as needed for your use case)
    allowed_origins = var.cors_allowed_origins
    # Allow common HTTP methods
    allowed_methods = ["GET", "HEAD"]
    # Allow common headers
    allowed_headers = ["*"]
    # Cache preflight requests for 1 hour
    max_age_seconds = 3600
  }
}

# Bucket policy that allows CloudFront OAC to access the bucket
# This is the key security feature - only CloudFront can access S3
resource "aws_s3_bucket_policy" "webgl_bucket_policy" {
  bucket = aws_s3_bucket.webgl_bucket.id

  # Policy document that grants access to CloudFront OAC
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow CloudFront OAC to get objects from the bucket
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.webgl_bucket.arn}/*"
        # Condition: Only allow if the request comes from the specified CloudFront distribution
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      }
    ]
  })

  # Wait for public access block to be applied first
  depends_on = [aws_s3_bucket_public_access_block.webgl_bucket_pab]
}

# Website configuration (optional, for index document)
resource "aws_s3_bucket_website_configuration" "webgl_bucket_website" {
  count = var.enable_website_config ? 1 : 0

  bucket = aws_s3_bucket.webgl_bucket.id

  # Set index.html as the default root object
  index_document {
    suffix = "index.html"
  }

  # Optional: Configure error document
  error_document {
    key = var.error_document
  }
}

