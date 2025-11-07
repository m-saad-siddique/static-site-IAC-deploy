# Environment Configuration Guide

## Overview

This project supports three environments:
- **dev** - Development (manual deployment, no IAM roles)
- **staging** - Staging (GitHub Actions OIDC enabled)
- **prod** - Production (GitHub Actions OIDC enabled)

## Configuration Status

### Development (dev)
- ✅ Manual deployment only
- ❌ IAM resources disabled
- ✅ Uses AWS profile (`deploy-config`)

### Staging (staging)
- ✅ GitHub Actions OIDC enabled
- ✅ IAM role for automated deployment
- ⚠️ **Action Required**: Update `github_actions_oidc` with your values

### Production (prod)
- ✅ GitHub Actions OIDC enabled
- ✅ IAM role for automated deployment
- ⚠️ **Action Required**: Update `github_actions_oidc` with your values

## Setup Instructions

### Step 1: Get Your AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

### Step 2: Update Staging Configuration

Edit `environments/staging/terraform.tfvars`:

```hcl
github_actions_oidc = {
  account_id        = "123456789012"  # Your AWS Account ID
  repository_filter = "repo:your-username/your-repo:*"  # Your GitHub repo
}
```

**Repository Filter Options:**
- `"repo:owner/repo:*"` - All branches in the repository
- `"repo:owner/repo:ref:refs/heads/staging"` - Only staging branch
- `"repo:owner/repo:environment:staging"` - Only staging environment

### Step 3: Update Production Configuration

Edit `environments/prod/terraform.tfvars`:

```hcl
github_actions_oidc = {
  account_id        = "123456789012"  # Your AWS Account ID
  repository_filter = "repo:your-username/your-repo:*"  # Your GitHub repo
}
```

**Repository Filter Options:**
- `"repo:owner/repo:*"` - All branches
- `"repo:owner/repo:ref:refs/heads/main"` - Only main branch
- `"repo:owner/repo:environment:production"` - Only production environment

### Step 4: Apply Terraform

```bash
# Staging
./scripts/plan.sh staging
./scripts/apply.sh staging

# Production
./scripts/plan.sh prod
./scripts/apply.sh prod
```

### Step 5: Get Role ARNs

```bash
# Staging role ARN
./scripts/outputs.sh staging | grep deployment_role_arn

# Production role ARN
./scripts/outputs.sh prod | grep deployment_role_arn
```

Use these ARNs in your GitHub Actions workflows.

## GitHub Actions Workflow Example

See `GITHUB_ACTIONS_SETUP.md` for complete workflow examples.

## Notes

- **Dev environment**: No changes needed - uses AWS profile for manual deployment
- **Staging/Prod**: Must configure `github_actions_oidc` before applying
- Each environment gets its own IAM role
- OIDC provider is created automatically (one per AWS account)

