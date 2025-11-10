# GitHub Secrets Setup

This document explains which GitHub Secrets you need to configure for CI/CD workflows.

## Required Secrets

### 1. AWS_ROLE_ARN_STAGING
- **Description**: IAM Role ARN for staging environment (created by `setup-iam-oidc.sh`)
- **How to get**: Run `./scripts/setup-iam-oidc.sh staging <account_id> <repo>` and copy the Role ARN from output
- **Example**: `arn:aws:iam::123456789012:role/webgl-staging-deployment-role`

### 2. AWS_ROLE_ARN_PROD
- **Description**: IAM Role ARN for production environment (created by `setup-iam-oidc.sh`)
- **How to get**: Run `./scripts/setup-iam-oidc.sh prod <account_id> <repo>` and copy the Role ARN from output
- **Example**: `arn:aws:iam::123456789012:role/webgl-prod-deployment-role`

### 3. AWS_ACCOUNT_ID
- **Description**: Your AWS Account ID (used for OIDC configuration)
- **How to get**: Run `aws sts get-caller-identity --query Account --output text`
- **Example**: `123456789012`

## Optional Secrets

### AWS_ROLE_ARN_DEV (if using dev CI/CD)
- **Description**: IAM Role ARN for dev environment
- **Note**: Dev is typically deployed locally, so this may not be needed

## How to Add Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the name and value above

## Verification

After adding secrets, the workflows will:
- Use `AWS_ROLE_ARN_STAGING` / `AWS_ROLE_ARN_PROD` for OIDC authentication
- Use `AWS_ACCOUNT_ID` to configure GitHub Actions OIDC in Terraform

## Troubleshooting

**Error: "Role ARN not found"**
- Make sure you've created the IAM role using `setup-iam-oidc.sh`
- Verify the role ARN is correct in GitHub Secrets

**Error: "AWS_ACCOUNT_ID not set"**
- Add `AWS_ACCOUNT_ID` secret to GitHub
- Get your account ID: `aws sts get-caller-identity --query Account --output text`

