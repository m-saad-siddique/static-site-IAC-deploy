# IAM Module - Creates IAM roles and policies for WebGL deployment
# This module can be used to create roles for CI/CD pipelines or deployment scripts
# Note: Provider requirements are defined in the root module (versions.tf)
# Note: OIDC provider is created separately by setup-iam-oidc.sh script

# IAM policy document for S3 upload access
# Allows uploading files to the S3 bucket
data "aws_iam_policy_document" "s3_upload_policy" {
  statement {
    sid    = "AllowS3Upload"
    effect = "Allow"

    # Allow actions on the bucket
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]

    # Resources: bucket and all objects in the bucket
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

# IAM policy document for CloudFront invalidation
# Allows creating CloudFront invalidations
data "aws_iam_policy_document" "cloudfront_invalidation_policy" {
  statement {
    sid    = "AllowCloudFrontInvalidation"
    effect = "Allow"

    # Allow creating invalidations
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations"
    ]

    # Resource: specific CloudFront distribution
    resources = [
      var.cloudfront_distribution_arn
    ]
  }
}

# Combined policy document for deployment
# Combines S3 upload and CloudFront invalidation permissions
data "aws_iam_policy_document" "deployment_policy" {
  # Include S3 upload policy
  source_policy_documents = [
    data.aws_iam_policy_document.s3_upload_policy.json,
    data.aws_iam_policy_document.cloudfront_invalidation_policy.json
  ]
}

# IAM policy for deployment
# This policy can be attached to users, roles, or groups
resource "aws_iam_policy" "deployment_policy" {
  count = var.create_deployment_policy ? 1 : 0

  name        = "${var.policy_name_prefix}-deployment-policy"
  description = "Policy for deploying WebGL builds to S3 and invalidating CloudFront"
  policy      = data.aws_iam_policy_document.deployment_policy.json

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.policy_name_prefix}-deployment-policy"
      Environment = var.environment
    }
  )
}

# IAM role for deployment (optional)
# This role can be assumed by CI/CD systems or EC2 instances
resource "aws_iam_role" "deployment_role" {
  count = var.create_deployment_role ? 1 : 0

  name = "${var.role_name_prefix}-deployment-role"

  # Assume role policy - who can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Support for AWS service principals (EC2, etc.)
      length(var.assume_role_services) > 0 ? [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = var.assume_role_services
          }
        }
      ] : [],
      # Support for GitHub Actions OIDC
      var.github_actions_oidc != null ? [
        {
          Action = "sts:AssumeRoleWithWebIdentity"
          Effect = "Allow"
          Principal = {
            Federated = "arn:aws:iam::${var.github_actions_oidc.account_id}:oidc-provider/token.actions.githubusercontent.com"
          }
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = var.github_actions_oidc.repository_filter
            }
          }
        }
      ] : []
    )
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.role_name_prefix}-deployment-role"
      Environment = var.environment
    }
  )
}

# Attach deployment policy to the role
resource "aws_iam_role_policy_attachment" "deployment_role_policy" {
  count = var.create_deployment_role && var.create_deployment_policy ? 1 : 0

  role       = aws_iam_role.deployment_role[0].name
  policy_arn = aws_iam_policy.deployment_policy[0].arn
}

