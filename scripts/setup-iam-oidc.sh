#!/bin/bash

# Script to create IAM role and policy for GitHub Actions OIDC
# Run this BEFORE deploying with Terraform for the first time

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if environment argument is provided
if [ $# -lt 3 ]; then
    print_error "Usage: $0 <environment> <aws_account_id> <github_repo>"
    echo ""
    echo "Example:"
    echo "  $0 staging 123456789012 myusername/my-repo"
    echo ""
    echo "Arguments:"
    echo "  environment    - Environment name (dev, staging, prod)"
    echo "  aws_account_id - Your AWS Account ID"
    echo "  github_repo   - GitHub repository (format: owner/repo)"
    exit 1
fi

ENVIRONMENT="$1"
AWS_ACCOUNT_ID="$2"
GITHUB_REPO="$3"
PROFILE="${AWS_PROFILE_NAME:-deploy-config}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Environment must be: dev, staging, or prod"
    exit 1
fi

# Check AWS CLI
if ! command -v aws >/dev/null 2>&1; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Check AWS profile
if ! aws configure list-profiles 2>/dev/null | grep -qx "${PROFILE}"; then
    print_error "AWS profile '${PROFILE}' is not configured"
    echo "Run: aws configure --profile ${PROFILE}"
    exit 1
fi

export AWS_PROFILE="${PROFILE}"

# Verify AWS account ID matches
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
if [ "$CURRENT_ACCOUNT" != "$AWS_ACCOUNT_ID" ]; then
    print_warning "Provided Account ID ($AWS_ACCOUNT_ID) doesn't match current account ($CURRENT_ACCOUNT)"
    read -p "Continue anyway? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        exit 0
    fi
fi

print_info "Setting up IAM OIDC for environment: ${ENVIRONMENT}"
print_info "AWS Account: ${AWS_ACCOUNT_ID}"
print_info "GitHub Repo: ${GITHUB_REPO}"
echo ""

# Step 1: Create OIDC Provider (if it doesn't exist)
print_info "Step 1: Creating OIDC Provider for GitHub Actions..."

OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" &>/dev/null; then
    print_info "OIDC Provider already exists"
else
    print_info "Creating OIDC Provider..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd \
        --tags Key=Name,Value=github-actions-oidc Key=Environment,Value=${ENVIRONMENT} 2>/dev/null || true
    
    if [ $? -eq 0 ]; then
        print_info "✅ OIDC Provider created"
    else
        print_warning "OIDC Provider may already exist or creation failed"
    fi
fi

# Step 2: Create IAM Policy
print_info "Step 2: Creating IAM Policy..."

POLICY_NAME="webgl-${ENVIRONMENT}-deployment-policy"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

# Initialize variable
POLICY_EXISTS=false

# Check if policy exists
if aws iam get-policy --policy-arn "${POLICY_ARN}" &>/dev/null; then
    print_warning "Policy ${POLICY_NAME} already exists"
    read -p "Delete and recreate? (y/n): " RECREATE
    if [ "$RECREATE" = "y" ]; then
        # Detach from all roles first
        aws iam list-entities-for-policy --policy-arn "${POLICY_ARN}" --query 'PolicyRoles[].RoleName' --output text | \
        xargs -I {} aws iam detach-role-policy --role-name {} --policy-arn "${POLICY_ARN}" 2>/dev/null || true
        aws iam delete-policy --policy-arn "${POLICY_ARN}"
        print_info "Old policy deleted"
    else
        print_info "Using existing policy"
        POLICY_EXISTS=true
    fi
else
    POLICY_EXISTS=false
fi

if [ "$POLICY_EXISTS" = false ]; then
    # Create policy document with full Terraform deployment permissions
    # This includes permissions for creating S3, CloudFront, IAM resources, and uploading files
    POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3FullAccess",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketAcl",
        "s3:GetBucketVersioning",
        "s3:ListBucket",
        "s3:ListBucketVersions",
        "s3:PutBucketVersioning",
        "s3:PutBucketPolicy",
        "s3:GetBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:PutBucketCors",
        "s3:GetBucketCors",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": [
        "arn:aws:s3:::webgl-${ENVIRONMENT}-*",
        "arn:aws:s3:::webgl-${ENVIRONMENT}-*/*"
      ]
    },
    {
      "Sid": "AllowCloudFrontFullAccess",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:GetDistribution",
        "cloudfront:ListDistributions",
        "cloudfront:CreateOriginAccessControl",
        "cloudfront:UpdateOriginAccessControl",
        "cloudfront:DeleteOriginAccessControl",
        "cloudfront:GetOriginAccessControl",
        "cloudfront:ListOriginAccessControls",
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation",
        "cloudfront:ListInvalidations",
        "cloudfront:TagResource",
        "cloudfront:UntagResource",
        "cloudfront:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowIAMRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRoles",
        "iam:UpdateRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:ListRolePolicies",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:role/webgl-${ENVIRONMENT}-*"
      ]
    },
    {
      "Sid": "AllowIAMPolicyManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:ListPolicies",
        "iam:ListPolicyVersions",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:SetDefaultPolicyVersion",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:ListPolicyTags"
      ],
      "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/webgl-${ENVIRONMENT}-*"
      ]
    },
    {
      "Sid": "AllowOIDCProviderManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders",
        "iam:TagOpenIDConnectProvider",
        "iam:UntagOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviderTags"
      ],
      "Resource": [
        "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      ]
    },
    {
      "Sid": "AllowTerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Sid": "AllowDynamoDBStateLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/terraform-state-lock"
      ]
    },
    {
      "Sid": "AllowRandomResourceCreation",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

    print_info "Creating policy: ${POLICY_NAME}"
    aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document "${POLICY_DOC}" \
        --description "Policy for deploying WebGL builds to ${ENVIRONMENT} environment" \
        --tags Key=Environment,Value=${ENVIRONMENT} Key=ManagedBy,Value=Script
    
    print_info "✅ Policy created: ${POLICY_ARN}"
    print_info "Policy includes full Terraform deployment permissions for S3, CloudFront, and IAM"
fi

# Step 3: Create IAM Role with OIDC trust
print_info "Step 3: Creating IAM Role with OIDC trust..."

ROLE_NAME="webgl-${ENVIRONMENT}-deployment-role"

# Initialize variable
ROLE_EXISTS=false

# Trust policy for GitHub Actions OIDC
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
    print_warning "Role ${ROLE_NAME} already exists"
    read -p "Delete and recreate? (y/n): " RECREATE
    if [ "$RECREATE" = "y" ]; then
        # Detach policies first
        aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query 'AttachedPolicies[].PolicyArn' --output text | \
        xargs -I {} aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn {} 2>/dev/null || true
        aws iam delete-role --role-name "${ROLE_NAME}"
        print_info "Old role deleted"
    else
        print_info "Using existing role"
        ROLE_EXISTS=true
    fi
else
    ROLE_EXISTS=false
fi

if [ "$ROLE_EXISTS" = false ]; then
    print_info "Creating role: ${ROLE_NAME}"
    aws iam create-role \
        --role-name "${ROLE_NAME}" \
        --assume-role-policy-document "${TRUST_POLICY}" \
        --description "Role for GitHub Actions to deploy to ${ENVIRONMENT} environment" \
        --tags Key=Environment,Value=${ENVIRONMENT} Key=ManagedBy,Value=Script
    
    print_info "✅ Role created"
fi

# Step 4: Attach policy to role
print_info "Step 4: Attaching policy to role..."

if aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query "AttachedPolicies[?PolicyArn=='${POLICY_ARN}']" --output text | grep -q "${POLICY_ARN}"; then
    print_info "Policy already attached to role"
else
    aws iam attach-role-policy \
        --role-name "${ROLE_NAME}" \
        --policy-arn "${POLICY_ARN}"
    
    print_info "✅ Policy attached to role"
fi

# Step 5: Get Role ARN
ROLE_ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)

echo ""
print_info "✅ Setup complete!"
echo ""
print_info "Role ARN: ${ROLE_ARN}"
echo ""
print_info "Next steps:"
echo "1. Add this to GitHub Secrets:"
echo "   Name: AWS_ROLE_ARN_$(echo ${ENVIRONMENT} | tr '[:lower:]' '[:upper:]')"
echo "   Value: ${ROLE_ARN}"
echo ""
echo "2. Add AWS_ACCOUNT_ID to GitHub Secrets:"
echo "   Name: AWS_ACCOUNT_ID"
echo "   Value: ${AWS_ACCOUNT_ID}"
echo ""
echo "3. The policy includes full Terraform deployment permissions."
echo "   You can now run Terraform in CI/CD to create infrastructure."
echo ""
print_info "✅ Ready for CI/CD deployment!"

