# Static Site Deployment with Terraform

A complete infrastructure-as-code solution for deploying static websites to AWS using S3 and CloudFront. This project provides secure, scalable hosting with automated CI/CD pipelines for multiple environments.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Local Development Setup](#local-development-setup)
- [Deploying to Dev Environment](#deploying-to-dev-environment)
- [CI/CD Setup for Staging & Production](#cicd-setup-for-staging--production)
- [State Management](#state-management)
- [Scripts Reference](#scripts-reference)
- [Troubleshooting](#troubleshooting)
- [Additional Documentation](#additional-documentation)

---

## Overview

This Terraform project automates the deployment of static websites to AWS with the following features:

- **Private S3 Buckets** - Secure storage for static assets
- **CloudFront CDN** - Global content delivery with caching
- **Origin Access Control (OAC)** - Restricts S3 access to CloudFront only
- **Multi-Environment Support** - Separate dev, staging, and production environments
- **Terraform Workspaces** - Isolated state management per environment
- **CI/CD Integration** - Automated deployments via GitHub Actions
- **OIDC Authentication** - Secure AWS access without storing credentials

---

## Architecture

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│   CloudFront    │ ◄─── Global CDN Distribution
│   Distribution  │
└────────┬────────┘
         │
         │ (OAC)
         ▼
┌─────────────────┐
│   S3 Bucket     │ ◄─── Private Static Assets Storage
│   (Private)     │
└─────────────────┘
```

**Key Components:**
- **S3 Bucket**: Stores static website files (HTML, CSS, JS, images, etc.)
- **CloudFront Distribution**: Serves content globally with edge caching
- **Origin Access Control (OAC)**: Ensures only CloudFront can access S3
- **IAM Roles**: Secure access for CI/CD deployments via GitHub Actions OIDC

---

## Prerequisites

Before you begin, ensure you have:

1. **Terraform** (≥ 1.0) - [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
2. **AWS CLI** - [Installation Guide](https://aws.amazon.com/cli/)
3. **Git** - For version control
4. **AWS Account** - With appropriate permissions
5. **GitHub Account** - For CI/CD (staging/prod only)

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/m-saad-siddique/static-site-IAC-deploy.git
cd static-site-deploy
```

### 2. Configure AWS Profile

Create an AWS profile named `deploy-config`:

```bash
aws configure --profile deploy-config
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter default output format (json)

# Verify the profile works:
aws sts get-caller-identity --profile deploy-config
```

> **Note**: See [AWS_PROFILE_SETUP.md](AWS_PROFILE_SETUP.md) for detailed instructions.

### 3. Deploy Dev Environment (Local)

```bash
# Initialize Terraform
./scripts/init.sh

# Plan the deployment
./scripts/plan.sh dev

# Apply the infrastructure
./scripts/apply.sh dev

# Upload your static site
./scripts/upload.sh dev ./path/to/your/static-site-build

# View outputs (CloudFront URL, S3 bucket name)
./scripts/outputs.sh dev
```

That's it! Your static site is now live on CloudFront.

---

## Local Development Setup

### Project Structure

```
.
├── main.tf                    # Root Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── versions.tf                # Provider versions and backend config
├── modules/                   # Reusable Terraform modules
│   ├── s3/                    # S3 bucket module
│   └── cloudfront/            # CloudFront distribution module
├── environments/              # Environment-specific configurations
│   ├── dev/
│   │   └── terraform.tfvars   # Dev environment variables
│   ├── staging/
│   │   └── terraform.tfvars   # Staging environment variables
│   └── prod/
│       └── terraform.tfvars   # Production environment variables
├── backend/                   # Remote state backend configurations
│   ├── staging.hcl            # Staging backend config
│   └── prod.hcl               # Production backend config
├── scripts/                   # Helper scripts
│   ├── init.sh                # Initialize Terraform
│   ├── plan.sh                # Create Terraform plan
│   ├── apply.sh               # Apply Terraform changes
│   ├── destroy.sh             # Destroy infrastructure
│   ├── upload.sh              # Upload files to S3
│   ├── outputs.sh             # Display outputs
│   ├── setup-iam-oidc.sh      # Setup IAM for CI/CD
│   └── setup-remote-state.sh  # Setup remote state backend
└── sample/                    # Sample files
    └── index.html             # Tutorial landing page
```

### Environment Configuration

Each environment has its own `terraform.tfvars` file in `environments/<env>/`:

**Example: `environments/dev/terraform.tfvars`**
```hcl
environment = "dev"
aws_region  = "us-east-1"
bucket_name = "static-site-deploy-dev"
```

You can customize:
- `bucket_name` - S3 bucket name (must be globally unique)
- `aws_region` - AWS region for resources
- `cache_ttl` - CloudFront cache TTL in seconds
- `default_root_object` - Default file to serve (usually "index.html")

---

## Deploying to Dev Environment

### Step-by-Step Deployment

1. **Initialize Terraform** (first time only)
   ```bash
   ./scripts/init.sh
   ```
   This sets up Terraform and creates the `dev` workspace.

2. **Review the Plan**
   ```bash
   ./scripts/plan.sh dev
   ```
   Review the planned changes. The plan is saved to `tfplan-dev.out`.

3. **Apply Changes**
   ```bash
   ./scripts/apply.sh dev
   ```
   This creates:
   - S3 bucket (private, no public access)
   - CloudFront distribution
   - Origin Access Control (OAC)
   - Bucket policy allowing CloudFront access only

4. **Upload Static Site**
   ```bash
   ./scripts/upload.sh dev ./path/to/your/build
   ```
   This:
   - Syncs files to S3
   - Invalidates CloudFront cache
   - Ensures your latest changes are live

5. **View Outputs**
   ```bash
   ./scripts/outputs.sh dev
   ```
   You'll see:
   - `cloudfront_url` - Your site's CloudFront URL
   - `s3_bucket_id` - S3 bucket name
   - `distribution_id` - CloudFront distribution ID

### Destroying Dev Environment

```bash
./scripts/destroy.sh dev
```

This removes all resources. The script will ask for confirmation.

---

## CI/CD Setup for Staging & Production

Staging and production environments use GitHub Actions for automated deployments. This requires one-time setup.

### Overview

- **Staging**: Deploys automatically when code is pushed to the `staging` branch
- **Production**: Deploys automatically when code is pushed to the `main` branch
- **Authentication**: Uses OIDC (OpenID Connect) - no AWS keys stored in GitHub
- **State Management**: Uses S3 backend with DynamoDB locking

### Step 1: Setup Remote State Backend

Create the S3 bucket and DynamoDB table for Terraform state:

```bash
# For staging
./scripts/setup-remote-state.sh staging

# For production
./scripts/setup-remote-state.sh prod
```

This script:
- Creates an S3 bucket for state storage
- Creates a DynamoDB table for state locking
- Updates `backend/<env>.hcl` with the resource names

**Important**: Commit `backend/staging.hcl` and `backend/prod.hcl` to Git.

### Step 2: Create IAM Role for GitHub Actions

Run the setup script for each environment:

```bash
# Get your AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile deploy-config --query Account --output text)

# Setup staging
./scripts/setup-iam-oidc.sh staging $AWS_ACCOUNT_ID m-saad-siddique/static-site-IAC-deploy

# Setup production
./scripts/setup-iam-oidc.sh prod $AWS_ACCOUNT_ID m-saad-siddique/static-site-IAC-deploy
```

**Replace** `m-saad-siddique/static-site-IAC-deploy` with your GitHub repository (owner/repo).

The script outputs:
- IAM Role ARN (e.g., `arn:aws:iam::123456789012:role/static-site-deploy-staging-deployment-role`)
- Instructions for GitHub Secrets

### Step 3: Configure GitHub Secrets

Add these secrets to your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add the following secrets:

| Secret Name | Value | Example |
|------------|-------|---------|
| `AWS_ACCOUNT_ID` | Your AWS Account ID | `123456789012` |
| `AWS_ROLE_ARN_STAGING` | Staging IAM Role ARN | `arn:aws:iam::123456789012:role/...` |
| `AWS_ROLE_ARN_PROD` | Production IAM Role ARN | `arn:aws:iam::123456789012:role/...` |

> **Note**: See [.github/GITHUB_SECRETS_SETUP.md](.github/GITHUB_SECRETS_SETUP.md) for detailed instructions.

### Step 4: Deploy via CI/CD

Once configured, deployments happen automatically:

```bash
# Deploy to staging
git checkout staging
git push origin staging

# Deploy to production (after staging is tested)
git checkout main
git push origin main
```

The GitHub Actions workflows (`.github/workflows/deploy-staging.yml` and `deploy-prod.yml`) will:
1. Assume the IAM role via OIDC
2. Initialize Terraform with remote state
3. Plan and apply changes
4. Upload static site files
5. Invalidate CloudFront cache

### Branch Protection (Recommended)

To enforce the workflow (`dev` → `staging` → `main`), set up branch protection rules:

1. Go to **Settings** → **Branches**
2. Add rules for `staging` and `main`:
   - Require pull request reviews
   - Require branches to be up to date
   - Do not allow force pushes
   - Do not allow deletions

See [.github/BRANCH_PROTECTION_SETUP.md](.github/BRANCH_PROTECTION_SETUP.md) for details.

---

## State Management

### Remote State (Staging & Production)

Staging and production use **remote state** stored in S3:

- **Location**: `s3://terraform-state-<env>/static-site-deploy/<env>/terraform.tfstate`
- **Locking**: DynamoDB table prevents concurrent modifications
- **Versioning**: S3 versioning allows state rollback
- **Backend Config**: Defined in `backend/<env>.hcl`

**Benefits:**
- Multiple team members can collaborate
- State is backed up automatically
- Prevents conflicts with state locking
- Works seamlessly with CI/CD

### Local State (Dev)

Development uses **local state** by default:

- **Location**: `.terraform/terraform.tfstate.d/dev/terraform.tfstate`
- **No locking**: Only one person should work on dev at a time
- **No backend config**: Dev doesn't use `backend/dev.hcl` (unless you create one)

**To convert dev to remote state:**
```bash
# Copy backend template
cp backend/staging.hcl backend/dev.hcl
# Edit backend/dev.hcl with dev-specific bucket/table names
./scripts/init.sh dev  # Reinitialize with remote backend
```

### State Rollback

If you need to restore a previous state:

1. **For Remote State (S3)**:
   ```bash
   # List state versions
   aws s3api list-object-versions \
     --bucket terraform-state-staging \
     --prefix static-site-deploy/staging/terraform.tfstate \
     --profile deploy-config
   
   # Restore a specific version
   aws s3api get-object \
     --bucket terraform-state-staging \
     --key static-site-deploy/staging/terraform.tfstate \
     --version-id <VERSION_ID> \
     terraform.tfstate \
     --profile deploy-config
   
   # Upload restored state
   aws s3 cp terraform.tfstate \
     s3://terraform-state-staging/static-site-deploy/staging/terraform.tfstate \
     --profile deploy-config
   ```

2. **For Local State**: Use Git to restore `.terraform/terraform.tfstate.d/dev/terraform.tfstate`

---

## Scripts Reference

All scripts are in the `scripts/` directory. They automatically:
- Check for required tools (Terraform, AWS CLI)
- Validate AWS profile configuration
- Handle workspace selection
- Initialize Terraform when needed

### Core Scripts

| Script | Usage | Description |
|--------|-------|-------------|
| `init.sh` | `./scripts/init.sh [env]` | Initialize Terraform, create workspace |
| `plan.sh` | `./scripts/plan.sh <env>` | Create Terraform execution plan |
| `apply.sh` | `./scripts/apply.sh <env> [--auto-approve]` | Apply Terraform changes |
| `destroy.sh` | `./scripts/destroy.sh <env> [--auto-approve]` | Destroy all resources |
| `outputs.sh` | `./scripts/outputs.sh <env>` | Display Terraform outputs |
| `upload.sh` | `./scripts/upload.sh <env> <path>` | Upload files to S3 and invalidate CloudFront |

### Setup Scripts

| Script | Usage | Description |
|--------|-------|-------------|
| `setup-remote-state.sh` | `./scripts/setup-remote-state.sh <env>` | Create S3 bucket and DynamoDB table for remote state |
| `setup-iam-oidc.sh` | `./scripts/setup-iam-oidc.sh <env> <account_id> <repo>` | Create IAM role and policy for GitHub Actions OIDC |

### Examples

```bash
# Initialize for dev (local state)
./scripts/init.sh

# Plan staging deployment (remote state)
./scripts/plan.sh staging

# Apply with auto-approve (skip confirmation)
./scripts/apply.sh dev --auto-approve

# Upload static site build
./scripts/upload.sh dev ./dist

# View CloudFront URL
./scripts/outputs.sh dev
```

> **Note**: See [scripts/README.md](scripts/README.md) for detailed documentation.

---

## Troubleshooting

### Common Issues

#### 1. AWS Profile Not Found

**Error**: `Failed to get AWS profile: deploy-config`

**Solution**:
```bash
aws configure --profile deploy-config
aws sts get-caller-identity --profile deploy-config
```

#### 2. Workspace Not Found

**Error**: `Workspace "dev" does not exist`

**Solution**:
```bash
./scripts/plan.sh dev  # Automatically creates workspace
```

#### 3. Access Denied in CI/CD

**Error**: `AccessDenied: User is not authorized to perform: s3:CreateBucket`

**Solution**: Update IAM policy permissions:
```bash
./scripts/setup-iam-oidc.sh staging <account_id> <repo>
# This updates the policy with all required permissions
```

#### 4. State Lock Error

**Error**: `Error acquiring the state lock`

**Solution**: 
- Wait for the other operation to complete
- Or manually unlock (if safe):
  ```bash
  aws dynamodb delete-item \
    --table-name terraform-state-lock-staging \
    --key '{"LockID":{"S":"static-site-deploy/staging/terraform.tfstate-md5"}}' \
    --profile deploy-config
  ```

#### 5. Bucket Not Empty During Destroy

**Error**: `BucketNotEmpty: The bucket you tried to delete is not empty`

**Solution**: The bucket has `force_destroy = true`, so Terraform should empty it. If it fails:
```bash
# Manually empty the bucket
aws s3 rm s3://bucket-name --recursive --profile deploy-config
# Then destroy again
./scripts/destroy.sh dev
```

#### 6. CloudFront OAC Already Exists

**Error**: `OriginAccessControlAlreadyExists`

**Solution**: The OAC name includes a unique suffix. If you see this, delete the old OAC:
```bash
aws cloudfront list-origin-access-controls --profile deploy-config
aws cloudfront delete-origin-access-control --id <OAC_ID> --profile deploy-config
```

#### 7. Backend Configuration Not Found

**Error**: `Failed to read backend configuration`

**Solution**: Ensure `backend/<env>.hcl` exists and contains valid values:
```bash
cat backend/staging.hcl
# Should show bucket, key, region, dynamodb_table
```

### Getting Help

- Check script logs for detailed error messages
- Review [Terraform documentation](https://www.terraform.io/docs)
- See [Additional Documentation](#additional-documentation) below

---

## Additional Documentation

This project includes comprehensive guides:

| Document | Description |
|----------|-------------|
| [scripts/README.md](scripts/README.md) | Detailed script documentation |
| [WORKSPACES_GUIDE.md](WORKSPACES_GUIDE.md) | How Terraform workspaces work |
| [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) | CI/CD setup guide |
| [IAM_ROLE_GUIDE.md](IAM_ROLE_GUIDE.md) | IAM roles and OIDC explained |
| [AWS_PROFILE_SETUP.md](AWS_PROFILE_SETUP.md) | AWS CLI profile configuration |
| [GIT_SETUP.md](GIT_SETUP.md) | Git workflow and best practices |
| [.github/GITHUB_SECRETS_SETUP.md](.github/GITHUB_SECRETS_SETUP.md) | GitHub Secrets configuration |
| [.github/BRANCH_PROTECTION_SETUP.md](.github/BRANCH_PROTECTION_SETUP.md) | Branch protection rules |
| [backend/README.md](backend/README.md) | Remote state backend guide |
| [environments/README.md](environments/README.md) | Environment configuration guide |

---

## Project Workflow

### Development Workflow

```
1. Make changes locally
   ↓
2. Test in dev environment
   ./scripts/apply.sh dev
   ./scripts/upload.sh dev ./build
   ↓
3. Commit and push to dev branch
   git push origin dev
   ↓
4. Create PR: dev → staging
   ↓
5. Merge to staging (triggers CI/CD)
   ↓
6. Test staging deployment
   ↓
7. Create PR: staging → main
   ↓
8. Merge to main (triggers production CI/CD)
```

### Branch Strategy

- **`dev`**: Local development and testing
- **`staging`**: Pre-production testing (CI/CD enabled)
- **`main`**: Production (CI/CD enabled)

**Rules:**
- No direct pushes to `staging` or `main` (use PRs)
- Always branch from `dev`
- Test in staging before production

---

## Security Best Practices

1. **Never commit secrets**: `.tfvars` files with real values should be in `.gitignore`
2. **Use OIDC for CI/CD**: No AWS keys stored in GitHub
3. **Least privilege IAM**: IAM roles only have permissions they need
4. **Private S3 buckets**: No public access, only CloudFront can read
5. **State encryption**: Remote state buckets use encryption at rest
6. **Branch protection**: Enforce code review before production

---

## Contributing

When contributing to this project:

1. **Keep secrets out of Git**: Use `.tfvars.example` as a template
2. **Format code**: Run `terraform fmt` before committing
3. **Validate changes**: Run `terraform validate`
4. **Test locally**: Always test in dev before creating PRs
5. **Document changes**: Update README and relevant docs

---

## License

This project is provided as-is for deploying static sites securely to AWS. Feel free to fork and adapt to your needs.

---

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Review the troubleshooting section
- Check the additional documentation

**Happy deploying! 🚀**
