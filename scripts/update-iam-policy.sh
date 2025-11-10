#!/bin/bash

# Script to update IAM policy with actual S3 bucket and CloudFront ARNs
# Run this AFTER Terraform deployment to update the policy with real resource ARNs

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ $# -ne 1 ]; then
    print_error "Usage: $0 <environment>"
    echo "Example: $0 staging"
    exit 1
fi

ENVIRONMENT="$1"
PROFILE="${AWS_PROFILE_NAME:-deploy-config}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Environment must be: dev, staging, or prod"
    exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
    print_error "Terraform is not installed"
    exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
    print_error "AWS CLI is not installed"
    exit 1
fi

if ! aws configure list-profiles 2>/dev/null | grep -qx "${PROFILE}"; then
    print_error "AWS profile '${PROFILE}' is not configured"
    exit 1
fi

export AWS_PROFILE="${PROFILE}"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

# Select workspace
if terraform workspace list | grep -q "^\s*${ENVIRONMENT}$"; then
    terraform workspace select "${ENVIRONMENT}"
else
    print_error "Workspace '${ENVIRONMENT}' does not exist. Run './scripts/apply.sh ${ENVIRONMENT}' first."
    exit 1
fi

# Get resource ARNs from Terraform
print_info "Getting resource ARNs from Terraform..."

S3_BUCKET_ARN=$(terraform output -raw s3_bucket_arn 2>/dev/null || echo "")
CLOUDFRONT_ARN=$(terraform output -raw cloudfront_distribution_arn 2>/dev/null || echo "")

if [ -z "$S3_BUCKET_ARN" ] || [ -z "$CLOUDFRONT_ARN" ]; then
    print_error "Could not get resource ARNs. Make sure Terraform deployment is complete."
    exit 1
fi

print_info "S3 Bucket ARN: ${S3_BUCKET_ARN}"
print_info "CloudFront ARN: ${CLOUDFRONT_ARN}"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/webgl-${ENVIRONMENT}-deployment-policy"

# Create updated policy document
POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Upload",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${S3_BUCKET_ARN}",
        "${S3_BUCKET_ARN}/*"
      ]
    },
    {
      "Sid": "AllowCloudFrontInvalidation",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation",
        "cloudfront:ListInvalidations"
      ],
      "Resource": "${CLOUDFRONT_ARN}"
    }
  ]
}
EOF
)

# Save policy to temp file
TEMP_POLICY=$(mktemp)
echo "${POLICY_DOC}" > "${TEMP_POLICY}"

# Create new policy version
print_info "Updating IAM policy with actual resource ARNs..."

aws iam create-policy-version \
    --policy-arn "${POLICY_ARN}" \
    --policy-document "file://${TEMP_POLICY}" \
    --set-as-default

# Clean up
rm "${TEMP_POLICY}"

print_info "✅ Policy updated successfully!"
print_info "The policy now has correct S3 bucket and CloudFront ARNs"

