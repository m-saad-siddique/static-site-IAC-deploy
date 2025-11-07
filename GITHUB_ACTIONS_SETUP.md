# GitHub Actions Setup Guide

## Quick Answer

**Yes, it can connect directly to GitHub Actions!** But you need to configure it first.

## What Gets Created

When you enable GitHub Actions OIDC:
1. **OIDC Provider** - Connects AWS to GitHub
2. **IAM Role** - Can be assumed by GitHub Actions
3. **Policy** - Permissions for deployment

## Step-by-Step Setup

### Step 1: Get Your AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

### Step 2: Configure Terraform

Edit `environments/prod/terraform.tfvars`:

```hcl
# IAM Configuration
create_iam_resources     = true
create_deployment_policy = true
create_deployment_role   = true

# Leave empty if using GitHub Actions
assume_role_services = []

# GitHub Actions OIDC Configuration
github_actions_oidc = {
  account_id        = "123456789012"  # Your AWS Account ID
  repository_filter = "repo:your-username/your-repo:*"  # Your GitHub repo
}
```

**Repository filter examples:**
- `"repo:owner/repo:*"` - All branches in one repo
- `"repo:owner/repo:ref:refs/heads/main"` - Only main branch
- `"repo:owner/repo:environment:production"` - Only production environment

### Step 3: Apply Terraform

```bash
./scripts/plan.sh prod
./scripts/apply.sh prod
```

This creates:
- OIDC Provider: `token.actions.githubusercontent.com`
- IAM Role: `webgl-prod-deployment-role`
- Policy: `webgl-prod-deployment-policy`

### Step 4: Get Role ARN

```bash
./scripts/outputs.sh prod
# Look for: deployment_role_arn
# Example: arn:aws:iam::123456789012:role/webgl-prod-deployment-role
```

### Step 5: Configure GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy WebGL

on:
  push:
    branches: [main]

permissions:
  id-token: write  # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/webgl-prod-deployment-role
          aws-region: us-east-1

      - name: Build WebGL
        run: |
          # Your build commands here
          # Example: unity -batchmode -quit -projectPath . -buildTarget WebGL

      - name: Upload to S3
        run: |
          BUCKET=$(aws s3 ls | grep webgl-prod | awk '{print $3}')
          aws s3 sync ./build s3://$BUCKET --delete

      - name: Invalidate CloudFront
        run: |
          DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='WebGL Build Distribution for prod'].Id" --output text)
          aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

### Step 6: Push to GitHub

```bash
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Actions deployment"
git push
```

## How It Works

1. **GitHub Actions runs** → Requests OIDC token from GitHub
2. **GitHub issues token** → Contains repo/branch info
3. **AWS validates token** → Checks OIDC provider + conditions
4. **AWS issues credentials** → Temporary (1 hour)
5. **GitHub Actions uses credentials** → Deploys to S3/CloudFront

## Security

✅ **No AWS keys stored in GitHub**  
✅ **Temporary credentials (auto-expire)**  
✅ **Scoped to specific repository**  
✅ **Can restrict to branches/environments**

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

- Check OIDC provider exists: `aws iam list-open-id-connect-providers`
- Verify repository filter matches your repo
- Ensure `id-token: write` permission in workflow

### Error: "The role defined cannot be assumed"

- Verify role ARN is correct
- Check OIDC provider is created
- Ensure GitHub Actions OIDC is configured in role trust policy

## Summary

**What you need:**
1. ✅ Configure `github_actions_oidc` in `terraform.tfvars`
2. ✅ Run `terraform apply`
3. ✅ Add GitHub Actions workflow with role ARN
4. ✅ Push to GitHub

**That's it!** No separate IAM users, no manual setup. Terraform creates everything.

