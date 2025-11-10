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

### Step 2: Configure remote state backend

Update `backend/prod.hcl` with:
- `bucket` → your Terraform state bucket (must exist and be unique)
- `key` → `webgl-deploy/prod/terraform.tfstate` (or any structure you prefer)
- `dynamodb_table` → table used for state locking

### Step 3: Create IAM role and OIDC provider

Run the helper script (one-time):

```bash
./scripts/setup-iam-oidc.sh prod <aws_account_id> <github_owner/repo>
```

The script:
- Creates the GitHub Actions OIDC provider (if needed)
- Creates the deployment policy/role with full Terraform permissions
- Prints the role ARN → add to GitHub secrets as `AWS_ROLE_ARN_PROD`
- Reminds you to add `AWS_ACCOUNT_ID` secret

### Step 4: Apply Terraform

```bash
./scripts/plan.sh prod
./scripts/apply.sh prod
```

This creates:
- S3 bucket + CloudFront distribution
- Remote state configuration remains in S3/DynamoDB
- Deployment role is already available (from the script)

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
1. ✅ Remote state backend configured (`backend/prod.hcl`)
2. ✅ IAM role & policy created via `scripts/setup-iam-oidc.sh`
3. ✅ Terraform applied (`./scripts/apply.sh prod`)
4. ✅ GitHub secrets `AWS_ACCOUNT_ID` + `AWS_ROLE_ARN_PROD`
5. ✅ GitHub Actions workflow using those secrets

**That's it!** No static IAM users, no long-lived keys—GitHub Actions authenticates via OIDC and assumes the role you created with the setup script.

