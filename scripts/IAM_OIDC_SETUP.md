# IAM OIDC Setup Scripts

These scripts help you set up IAM roles and policies for GitHub Actions OIDC **before** running Terraform.

## Why Use These Scripts?

- Create IAM resources separately from Terraform
- Get role ARN immediately for GitHub Secrets
- Test CI/CD before full Terraform deployment
- More control over IAM setup

## Scripts

### 1. `setup-iam-oidc.sh` - Create IAM Role and Policy

Creates OIDC provider, IAM policy, and IAM role for GitHub Actions.

**Usage:**
```bash
./scripts/setup-iam-oidc.sh <environment> <aws_account_id> <github_repo>
```

**Example:**
```bash
# For staging
./scripts/setup-iam-oidc.sh staging 123456789012 myusername/webgl-deploy

# For production
./scripts/setup-iam-oidc.sh prod 123456789012 myusername/webgl-deploy
```

**What it does:**
1. Creates OIDC provider for GitHub Actions (if not exists)
2. Creates IAM policy (with placeholder resources)
3. Creates IAM role with OIDC trust policy
4. Attaches policy to role
5. Outputs role ARN for GitHub Secrets

### 2. `update-iam-policy.sh` - Update Policy with Real ARNs

Updates the IAM policy with actual S3 bucket and CloudFront ARNs after Terraform deployment.

**Usage:**
```bash
./scripts/update-iam-policy.sh <environment>
```

**Example:**
```bash
# After deploying staging with Terraform
./scripts/update-iam-policy.sh staging

# After deploying prod with Terraform
./scripts/update-iam-policy.sh prod
```

**What it does:**
1. Gets S3 bucket ARN from Terraform
2. Gets CloudFront ARN from Terraform
3. Updates IAM policy with actual resource ARNs
4. Sets as default policy version

## Complete Workflow

### Step 1: Create IAM Role (Before Terraform)

```bash
# Get your AWS Account ID
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# Create staging role
./scripts/setup-iam-oidc.sh staging $AWS_ACCOUNT yourusername/your-repo

# Create production role
./scripts/setup-iam-oidc.sh prod $AWS_ACCOUNT yourusername/your-repo
```

### Step 2: Add Role ARNs to GitHub Secrets

The script outputs the role ARN. Add to GitHub:
- `AWS_ROLE_ARN_STAGING` = output from staging script
- `AWS_ROLE_ARN_PROD` = output from prod script

### Step 3: Deploy with Terraform

```bash
./scripts/apply.sh staging
./scripts/apply.sh prod
```

### Step 4: Update IAM Policy with Real ARNs

```bash
./scripts/update-iam-policy.sh staging
./scripts/update-iam-policy.sh prod
```

## Notes

- The initial policy uses wildcard resources (`webgl-${ENV}-*`)
- After Terraform deployment, update the policy with actual ARNs
- The role ARN is available immediately (before Terraform)
- OIDC provider is created once per AWS account (shared)

## Troubleshooting

**Error: "Role already exists"**
- Script will ask if you want to recreate
- Or manually delete: `aws iam delete-role --role-name webgl-staging-deployment-role`

**Error: "Policy already exists"**
- Script will ask if you want to recreate
- Or update manually with `update-iam-policy.sh`

**Policy needs updating**
- Always run `update-iam-policy.sh` after Terraform deployment
- This ensures policy has correct S3 and CloudFront ARNs

