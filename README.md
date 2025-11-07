# WebGL Deployment with Terraform

This Terraform configuration deploys a WebGL application to AWS S3 with CloudFront distribution, using Origin Access Control (OAC) for secure access.

## Architecture

- **S3 Bucket**: Private bucket storing WebGL build files (not publicly accessible)
- **CloudFront**: CDN distribution with OAC to securely access S3 bucket
- **IAM**: Optional roles and policies for deployment automation

## Directory Structure

```
.
├── main.tf                 # Root Terraform configuration
├── variables.tf            # Root variables
├── outputs.tf             # Root outputs
├── modules/
│   ├── s3/                # S3 bucket module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloudfront/        # CloudFront distribution module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/               # IAM roles and policies module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/               # Development environment
    │   └── terraform.tfvars
    ├── staging/           # Staging environment
    │   └── terraform.tfvars
    └── prod/              # Production environment
        └── terraform.tfvars
```

## Prerequisites

1. **AWS CLI** installed and configured
2. **Terraform** installed (version >= 1.0)
3. **AWS Account** with appropriate permissions

## AWS Profile Configuration

This project uses a specific AWS profile named `deploy-config` for authentication. You must configure this profile before running any deployment scripts.

### Step 1: Configure AWS Profile

You can configure the AWS profile using one of the following methods:

#### Method 1: Interactive Configuration (Recommended)

```bash
aws configure --profile deploy-config
```

You will be prompted to enter:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **Default region name**: e.g., `us-east-1`
- **Default output format**: `json` (recommended)

#### Method 2: Non-Interactive Configuration

```bash
aws configure set aws_access_key_id YOUR_ACCESS_KEY --profile deploy-config
aws configure set aws_secret_access_key YOUR_SECRET_KEY --profile deploy-config
aws configure set region us-east-1 --profile deploy-config
aws configure set output json --profile deploy-config
```

#### Method 3: Manual Configuration

Edit the AWS credentials and config files directly:

**~/.aws/credentials:**
```ini
[deploy-config]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

**~/.aws/config:**
```ini
[profile deploy-config]
region = us-east-1
output = json
```

### Step 2: Verify Profile Configuration

Verify that the profile is configured correctly:

```bash
# List all profiles
aws configure list-profiles

# Verify the profile exists
aws configure list-profiles | grep deploy-config

# Test the profile
aws sts get-caller-identity --profile deploy-config
```

### Step 3: Using a Different Profile Name

If you want to use a different profile name, set the `AWS_PROFILE_NAME` environment variable:

```bash
export AWS_PROFILE_NAME=my-custom-profile
./scripts/plan.sh dev
```

### Important Notes

- **All deployment scripts automatically check for the AWS profile** and will show an error if it's not configured
- The profile must have valid credentials with permissions to create S3 buckets, CloudFront distributions, and IAM resources
- The scripts validate the profile before running any Terraform commands
- If the profile is missing or invalid, the scripts will display helpful error messages with setup instructions

## Quick Start

### Option 1: Using Helper Scripts (Recommended)

The easiest way to deploy is using the provided scripts:

```bash
# 1. Initialize Terraform
./scripts/init.sh

# 2. Plan deployment
./scripts/plan.sh dev

# 3. Apply deployment
./scripts/apply.sh dev

# 4. View outputs
./scripts/outputs.sh dev
```

See [scripts/README.md](scripts/README.md) for detailed script documentation.

### Option 2: Using Terraform Directly

#### 1. Initialize Terraform

```bash
terraform init
```

#### 2. Deploy to Development Environment

```bash
# From the root directory
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

#### 3. Deploy to Other Environments

```bash
# Staging
terraform plan -var-file=environments/staging/terraform.tfvars
terraform apply -var-file=environments/staging/terraform.tfvars

# Production
terraform plan -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Configuration

### Environment Variables

Edit the `terraform.tfvars` files in the `environments/` directory to configure:

- **AWS Region**: Where resources will be created
- **Project Name**: Used for resource naming
- **CloudFront Settings**: Cache policies, TTL, price class
- **S3 Settings**: Versioning, CORS configuration
- **IAM Settings**: Whether to create deployment policies/roles

### Custom Domain Setup

To use a custom domain:

1. Request an ACM certificate in `us-east-1` region
2. Update `acm_certificate_arn` in your environment's `terraform.tfvars`
3. Update `cloudfront_aliases` with your domain names
4. Create a CNAME record in your DNS pointing to the CloudFront distribution domain

## Deployment

After Terraform creates the infrastructure:

1. Upload your WebGL build files to the S3 bucket
   - Use the helper script: `./scripts/upload.sh dev path/to/build` (also issues a CloudFront invalidation)
   - A placeholder build is available in `sample/index.html` for testing
2. Use the CloudFront distribution URL from the outputs to access your application

### Upload Script Example

```bash
#!/bin/bash
BUCKET_NAME=$(terraform output -raw s3_bucket_id)
LOCAL_DIR="./WebGLBuild"

aws s3 sync "$LOCAL_DIR" "s3://$BUCKET_NAME/" \
  --delete \
  --cache-control "max-age=31536000" \
  --exclude "*.html" \
  --exclude "*.json"

# Upload HTML files with shorter cache
aws s3 sync "$LOCAL_DIR" "s3://$BUCKET_NAME/" \
  --cache-control "max-age=3600" \
  --include "*.html" \
  --include "*.json"
```

## Outputs

After deployment, Terraform will output:

- `s3_bucket_id`: S3 bucket name
- `cloudfront_distribution_domain_name`: CloudFront URL
- `deployment_url`: Full HTTPS URL to access your WebGL build

## Security Features

- **Private S3 Bucket**: Bucket is not publicly accessible
- **OAC (Origin Access Control)**: Only CloudFront can access S3 bucket
- **HTTPS Only**: CloudFront redirects HTTP to HTTPS
- **Encryption**: S3 bucket uses server-side encryption

## Cleanup

To destroy all resources:

```bash
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Notes

- S3 bucket names must be globally unique (a random suffix is added)
- CloudFront distributions can take 15-20 minutes to deploy
- ACM certificates for CloudFront must be in `us-east-1` region
- The S3 bucket policy is automatically configured to allow CloudFront OAC access

