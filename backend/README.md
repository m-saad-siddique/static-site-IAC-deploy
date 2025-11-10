# Terraform Remote State Setup

This directory contains backend configuration files for Terraform remote state management.

## Quick Setup

Run the setup script to create S3 bucket and DynamoDB table:

```bash
# For staging
./scripts/setup-remote-state.sh staging

# For production
./scripts/setup-remote-state.sh prod
```

The script will:
1. ✅ Create S3 bucket for state storage
2. ✅ Create DynamoDB table for state locking
3. ✅ Configure bucket (versioning, encryption, public access block)
4. ✅ Update backend config files automatically

## Manual Setup

If you prefer to create resources manually:

### 1. Create S3 Bucket

```bash
aws s3api create-bucket --bucket terraform-state-ACCOUNT_ID-staging --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-ACCOUNT_ID-staging \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-ACCOUNT_ID-staging \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2. Create DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock-staging \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Update Backend Config

Edit `staging.hcl` or `prod.hcl` with your bucket and table names.

## File Structure

- `staging.hcl` - Backend config for staging environment
- `prod.hcl` - Backend config for production environment
- `README.md` - This file

## Usage

After setup, Terraform will automatically use remote state:

```bash
# Initialize with remote state
terraform init -backend-config=backend/staging.hcl

# Or use the scripts (they handle this automatically)
./scripts/init.sh staging
./scripts/plan.sh staging
./scripts/apply.sh staging
```

## Important Notes

- **One-time setup**: Run the setup script once per environment
- **State migration**: If you have existing local state, Terraform will prompt to migrate
- **CI/CD**: GitHub Actions workflows automatically use these backend configs
- **Dev environment**: Uses local state (no backend config needed)

## Troubleshooting

**Error: "Bucket already exists"**
- The bucket name must be globally unique
- Use a different name or delete the existing bucket

**Error: "Access Denied"**
- Ensure your IAM user/role has permissions for S3 and DynamoDB
- Required permissions:
  - `s3:CreateBucket`, `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`
  - `dynamodb:CreateTable`, `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:DeleteItem`

**Error: "Table already exists"**
- The table name must be unique in your account
- Use a different name or delete the existing table

