# WebGL Deployment with Terraform

This Terraform configuration deploys a WebGL application to AWS S3 with CloudFront distribution, using Origin Access Control (OAC) for secure access. Supports multiple environments (dev, staging, prod) with independent state management using Terraform workspaces.

## Architecture

- **S3 Bucket**: Private bucket storing WebGL build files (not publicly accessible)
- **CloudFront**: CDN distribution with OAC to securely access S3 bucket
- **IAM (via scripts)**: Deployment roles and policies created with `./scripts/setup-iam-oidc.sh`
- **Workspaces**: Separate state files for each environment (dev, staging, prod)

## Directory Structure

```
.
├── main.tf                 # Root Terraform configuration
├── variables.tf            # Root variables
├── outputs.tf             # Root outputs
├── versions.tf             # Terraform version constraints
├── backend/               # Remote state backend configuration (per environment)
├── modules/
│   ├── s3/                # S3 bucket module
│   ├── cloudfront/        # CloudFront distribution module
│   └── iam/               # IAM roles and policies module
├── environments/
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment
│   └── prod/              # Production environment
├── scripts/               # Deployment helper scripts
│   ├── init.sh           # Initialize Terraform
│   ├── plan.sh           # Plan deployment
│   ├── apply.sh          # Apply deployment
│   ├── destroy.sh        # Destroy resources
│   ├── outputs.sh        # View outputs
│   └── upload.sh         # Upload files to S3
└── sample/                # Sample files
    └── index.html         # Tutorial/placeholder page
```

## Prerequisites

1. **AWS CLI** installed and configured
2. **Terraform** installed (version >= 1.0)
3. **AWS Account** with appropriate permissions

## AWS Profile Configuration

This project uses a specific AWS profile named `deploy-config` for authentication. You must configure this profile before running any deployment scripts.

### Quick Setup

```bash
aws configure --profile deploy-config
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (`json`)

### Verify Configuration

```bash
aws sts get-caller-identity --profile deploy-config
```

See [AWS_PROFILE_SETUP.md](AWS_PROFILE_SETUP.md) for detailed instructions.

## Quick Start

### 1. Initialize Terraform

```bash
./scripts/init.sh
```

### 2. Deploy to Development

```bash
./scripts/plan.sh dev
./scripts/apply.sh dev
```

### 3. Upload Your Build

```bash
./scripts/upload.sh dev ./WebGLBuild
```

### 4. View Outputs

```bash
./scripts/outputs.sh dev
```

## Remote State (staging & prod)

Staging and production environments store their Terraform state in S3 for safe collaboration and CI/CD support.

1. **Create an S3 bucket and DynamoDB table** (one-time):
   ```bash
   aws s3api create-bucket --bucket <state-bucket-name> --region us-east-1
   aws dynamodb create-table \
     --table-name <lock-table-name> \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```
   > Replace the bucket and table names with values that match your naming standards. Buckets must be globally unique.

2. **Update backend configuration files:**
   - `backend/staging.hcl`
   - `backend/prod.hcl`

   Set `bucket`, `key`, `region`, and `dynamodb_table` to the resources you created. Leave `encrypt = true`.

3. **Run Terraform scripts normally.** The helper scripts detect the backend files and automatically pass `-backend-config` during `terraform init`.

4. **Developer workflow:**
   ```bash
   ./scripts/plan.sh staging   # Uses remote state backend/staging.hcl
   ./scripts/apply.sh staging
   ./scripts/plan.sh prod
   ./scripts/apply.sh prod
   ```

> Development (`dev`) continues to use local state by default. Add a `backend/dev.hcl` if you prefer remote state for dev as well.

## Multiple Environments

This project uses **Terraform workspaces** to manage multiple environments independently. Each environment has its own state file, allowing you to deploy and destroy them separately.

### Deploy All Environments

```bash
# Deploy dev
./scripts/plan.sh dev
./scripts/apply.sh dev

# Deploy staging (independent from dev)
./scripts/plan.sh staging
./scripts/apply.sh staging

# Deploy prod (independent from dev and staging)
./scripts/plan.sh prod
./scripts/apply.sh prod
```

### Destroy Specific Environment

```bash
# Destroy only staging (dev and prod remain untouched)
./scripts/destroy.sh staging

# Destroy only dev
./scripts/destroy.sh dev
```

**Benefits:**
- ✅ Separate state files per environment
- ✅ Safe to destroy any environment independently
- ✅ No conflicts between environments
- ✅ Automatic workspace management

See [WORKSPACES_GUIDE.md](WORKSPACES_GUIDE.md) for detailed workspace documentation.

## Deployment Methods

### Method 1: Manual Deployment (Development)

**Best for:** Development, testing, small teams

```bash
# Configure AWS profile
aws configure --profile deploy-config

# Deploy
./scripts/init.sh
./scripts/plan.sh dev
./scripts/apply.sh dev
./scripts/upload.sh dev ./build
```

**Pros:**
- Simple setup
- Works immediately
- Good for learning

**Cons:**
- Manual process
- Requires AWS keys

### Method 2: GitHub Actions with OIDC (Recommended for Production)

**Best for:** Automated CI/CD, production deployments

**Setup:**

1. **Configure remote state:** Update `backend/prod.hcl` with your Terraform state bucket and DynamoDB lock table.
2. **Create IAM role & policy:**  
   ```bash
   ./scripts/setup-iam-oidc.sh prod <aws_account_id> <github_owner/repo>
   ```
   The script prints the role ARN and reminds you to add `AWS_ACCOUNT_ID` + `AWS_ROLE_ARN_PROD` to GitHub secrets.
3. **Deploy infrastructure:**  
   ```bash
   ./scripts/plan.sh prod
   ./scripts/apply.sh prod
   ```
4. **Reference workflow template:** See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for GitHub Actions configuration.

**Pros:**
- ✅ No AWS keys stored in GitHub
- ✅ Temporary credentials (auto-expire)
- ✅ Fully automated
- ✅ Secure and auditable

### Method 3: EC2 Instance with IAM Role

**Best for:** Long-running build servers

**Setup:**

1. **Create a deployment IAM role** (custom trust policy for EC2). You can adapt `scripts/setup-iam-oidc.sh` or create the role manually via IAM.
2. **Configure remote state:** Update `backend/prod.hcl` to point at your state bucket/table.
3. **Deploy infrastructure:**  
   ```bash
   ./scripts/plan.sh prod
   ./scripts/apply.sh prod
   ```
4. **Attach the IAM role to your EC2 instance** so Terraform/CLI commands can run without long-lived credentials.

See [IAM_ROLE_GUIDE.md](IAM_ROLE_GUIDE.md) for detailed IAM setup instructions.

## Available Scripts

All scripts automatically handle workspaces and AWS profile validation.

| Script | Description |
|--------|-------------|
| `init.sh` | Initialize Terraform and show workspaces |
| `plan.sh <env>` | Create deployment plan for environment |
| `apply.sh <env>` | Deploy infrastructure for environment |
| `destroy.sh <env>` | Destroy resources for environment |
| `outputs.sh <env>` | View Terraform outputs |
| `upload.sh <env> <dir>` | Upload files to S3 and invalidate CloudFront |

See [scripts/README.md](scripts/README.md) for detailed documentation.

## Configuration

### Environment Configuration

Edit the `terraform.tfvars` files in `environments/` directory:

**Development (`environments/dev/terraform.tfvars`):**
- Manual deployment only
- IAM resources disabled
- Lower cache TTL

**Staging (`environments/staging/terraform.tfvars`):**
- Remote state configured via `backend/staging.hcl`
- IAM role created with `./scripts/setup-iam-oidc.sh staging ...`
- Medium cache TTL

**Production (`environments/prod/terraform.tfvars`):**
- Remote state configured via `backend/prod.hcl`
- IAM role created with `./scripts/setup-iam-oidc.sh prod ...`
- Long cache TTL
- Global CloudFront distribution

### Key Configuration Options

- **AWS Region**: Where resources are created
- **Project Name**: Used for resource naming
- **CloudFront Settings**: Cache policies, TTL, price class
- **S3 Settings**: Versioning, CORS configuration
- **IAM Settings**: Enable/disable deployment roles and policies
- **GitHub Actions OIDC**: Configure for automated deployments

See [environments/README.md](environments/README.md) for environment-specific configuration.

### Custom Domain Setup

1. Request an ACM certificate in `us-east-1` region
2. Update `acm_certificate_arn` in your environment's `terraform.tfvars`
3. Update `cloudfront_aliases` with your domain names
4. Create a CNAME record pointing to CloudFront distribution domain

## Uploading Files

### Using the Upload Script (Recommended)

```bash
# Upload and invalidate CloudFront cache
./scripts/upload.sh dev ./WebGLBuild

# Upload to subfolder
./scripts/upload.sh dev ./build webgl/
```

The script automatically:
- Syncs files to S3
- Creates CloudFront invalidation
- Uses correct AWS profile

### Manual Upload

```bash
# Get bucket name
BUCKET=$(./scripts/outputs.sh dev | grep s3_bucket_id)

# Upload files
aws s3 sync ./build s3://$BUCKET --delete --profile deploy-config

# Invalidate CloudFront
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*" --profile deploy-config
```

## Outputs

After deployment, view outputs:

```bash
./scripts/outputs.sh dev
```

**Key Outputs:**
- `s3_bucket_id`: S3 bucket name
- `cloudfront_distribution_domain_name`: CloudFront URL
- `deployment_url`: Full HTTPS URL
- `deployment_role_arn`: IAM role ARN (if enabled)

## Security Features

- **Private S3 Bucket**: Not publicly accessible
- **OAC (Origin Access Control)**: Only CloudFront can access S3
- **HTTPS Only**: CloudFront redirects HTTP to HTTPS
- **Encryption**: S3 bucket uses server-side encryption
- **IAM Roles**: Temporary credentials for automated deployments
- **Workspace Isolation**: Separate state files per environment

## Cleanup

### Destroy Specific Environment

```bash
# Destroy staging only
./scripts/destroy.sh staging

# Destroy dev only
./scripts/destroy.sh dev

# Destroy prod (with confirmation)
./scripts/destroy.sh prod
```

Each environment is destroyed independently - other environments remain untouched.

## Documentation

- **[scripts/README.md](scripts/README.md)** - Script usage and examples
- **[WORKSPACES_GUIDE.md](WORKSPACES_GUIDE.md)** - Workspace management
- **[GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)** - CI/CD setup
- **[IAM_ROLE_GUIDE.md](IAM_ROLE_GUIDE.md)** - IAM roles explained
- **[environments/README.md](environments/README.md)** - Environment configuration
- **[GIT_SETUP.md](GIT_SETUP.md)** - Git repository setup
- **[AWS_PROFILE_SETUP.md](AWS_PROFILE_SETUP.md)** - AWS profile configuration

## Important Notes

- **S3 bucket names** must be globally unique (random suffix added automatically)
- **CloudFront distributions** take 15-20 minutes to deploy
- **ACM certificates** for CloudFront must be in `us-east-1` region
- **Workspaces** are managed automatically by scripts
- **State files** are stored locally in `.terraform/terraform.tfstate.d/` (excluded from git)

## Troubleshooting

### Workspace Issues

```bash
# List all workspaces
terraform workspace list

# Show current workspace
terraform workspace show

# Select workspace manually
terraform workspace select staging
```

### AWS Profile Issues

```bash
# Verify profile exists
aws configure list-profiles | grep deploy-config

# Test profile
aws sts get-caller-identity --profile deploy-config
```

### Common Errors

- **"Workspace doesn't exist"** - Run `./scripts/plan.sh <env>` first (creates workspace)
- **"Profile not configured"** - Run `aws configure --profile deploy-config`
- **"No outputs found"** - Run `./scripts/apply.sh <env>` first

## Contributing

1. Review `.gitignore` before committing
2. Never commit `.tfvars` files with real values
3. Use `terraform.tfvars.example` as template
4. See [GIT_SETUP.md](GIT_SETUP.md) for details

## License

This project is provided as-is for deploying WebGL applications to AWS.
