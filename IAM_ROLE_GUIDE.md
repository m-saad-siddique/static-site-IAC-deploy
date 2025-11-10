# IAM Role Setup Guide - Step by Step

This guide explains how IAM roles work in this project and when you need them.

> **Update:** IAM roles and policies are now provisioned with `./scripts/setup-iam-oidc.sh`. The sections below provide background context and legacy Terraform examples. Follow the script-based workflow in the main README for production use.

## Understanding the Components

When you enable IAM resources, Terraform creates:

1. **IAM Policy** (`create_deployment_policy = true`)
   - Contains permissions: S3 upload + CloudFront invalidation
   - This is just a document - doesn't do anything by itself

2. **IAM Role** (`create_deployment_role = true`)
   - Can be "assumed" by services/users
   - Has the policy attached
   - Provides temporary credentials (tokens)

## Current Setup (No Role)

**What you have now:**
- Your AWS profile (`deploy-config`) with IAM keys
- Keys are permanent credentials
- Works for manual deployment

**Flow:**
```
You → AWS Profile (IAM Keys) → Deploy to S3/CloudFront
```

## When You Enable IAM Role

**What gets created:**
- IAM Policy: Permissions document
- IAM Role: Can be assumed by services
- Role has policy attached

**Flow:**
```
Service/User → Assume Role → Get Temporary Credentials → Deploy
```

## Step-by-Step Setup

### Scenario 1: For CI/CD (GitHub Actions, GitLab CI, etc.)

#### Step 1: Enable IAM Resources in Terraform

Edit `environments/prod/terraform.tfvars`:
```hcl
create_iam_resources     = true
create_deployment_policy = true
create_deployment_role   = true
assume_role_services     = ["ec2.amazonaws.com"]  # Default, but we'll change this
```

#### Step 2: Configure Role Trust for Your CI/CD Provider

The role needs to trust your CI/CD provider. Update the IAM module to support OIDC (for GitHub Actions):

**Option A: GitHub Actions (OIDC)**

You need to modify `modules/iam/main.tf` to support OIDC trust. The current setup only supports service principals.

**Option B: Use EC2 Service (Simpler)**

If your CI/CD runs on EC2, keep `assume_role_services = ["ec2.amazonaws.com"]` and attach the role to your EC2 instance.

#### Step 3: Apply Terraform

```bash
./scripts/plan.sh prod
./scripts/apply.sh prod
```

This creates:
- Policy: `webgl-prod-deployment-policy`
- Role: `webgl-prod-deployment-role`

#### Step 4: Get Role ARN

```bash
./scripts/outputs.sh prod
# Look for: deployment_role_arn
```

#### Step 5: Configure CI/CD to Use Role

**For GitHub Actions:**
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT_ID:role/webgl-prod-deployment-role
    aws-region: us-east-1

- name: Upload to S3
  run: aws s3 sync ./build s3://$(terraform output -raw s3_bucket_id)
```

**For GitLab CI:**
```yaml
deploy:
  script:
    - aws sts assume-role --role-arn arn:aws:iam::ACCOUNT_ID:role/webgl-prod-deployment-role --role-session-name gitlab
    - # Use temporary credentials
```

### Scenario 2: For EC2 Instance

#### Step 1: Enable IAM Role

```hcl
create_iam_resources     = true
create_deployment_policy = true
create_deployment_role   = true
assume_role_services     = ["ec2.amazonaws.com"]  # This is correct for EC2
```

#### Step 2: Apply Terraform

```bash
./scripts/apply.sh prod
```

#### Step 3: Attach Role to EC2 Instance

In AWS Console:
1. Go to EC2 → Instances
2. Select your instance
3. Actions → Security → Modify IAM role
4. Select `webgl-prod-deployment-role`
5. Save

Now your EC2 instance can deploy without storing keys!

### Scenario 3: For Manual Use (You Don't Need Role)

**Keep it disabled:**
```hcl
create_iam_resources     = false  # or true, doesn't matter
create_deployment_policy = false
create_deployment_role   = false  # Keep false for manual deployment
```

**Use your AWS profile:**
```bash
aws configure --profile deploy-config
./scripts/upload.sh prod ./build
```

## Do You Need Separate IAM Users?

**Short answer: NO**

The IAM role is self-contained. You don't need to create:
- Separate IAM users
- Additional policies
- Manual role attachments

**What Terraform creates is enough:**
- ✅ Policy (permissions)
- ✅ Role (can be assumed)
- ✅ Policy attached to role

## Complete Flow Comparison

### Without Role (Current - Manual Deployment)

```
1. You have IAM user with keys
2. Keys stored in ~/.aws/credentials
3. Scripts use keys directly
4. Deploy to S3/CloudFront
```

**Pros:**
- Simple
- Works immediately
- No extra setup

**Cons:**
- Keys are permanent (security risk if leaked)
- Hard to rotate
- Can't use in CI/CD easily

### With Role (Automated Deployment)

```
1. Terraform creates role + policy
2. CI/CD system assumes role
3. Gets temporary credentials (1 hour expiry)
4. Uses temp credentials to deploy
5. Credentials expire automatically
```

**Pros:**
- Temporary credentials (more secure)
- No keys to store in CI/CD
- Automatic expiration
- Better audit trail

**Cons:**
- More setup required
- Need to configure trust relationship

## What Gets Created (Technical Details)

When `create_deployment_role = true`:

1. **IAM Policy** (`webgl-prod-deployment-policy`)
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "s3:PutObject",
       "s3:GetObject",
       "s3:DeleteObject",
       "s3:ListBucket",
       "cloudfront:CreateInvalidation"
     ],
     "Resource": [
       "arn:aws:s3:::bucket-name",
       "arn:aws:s3:::bucket-name/*",
       "arn:aws:cloudfront::ACCOUNT:distribution/DIST_ID"
     ]
   }
   ```

2. **IAM Role** (`webgl-prod-deployment-role`)
   - Trust policy: Allows `ec2.amazonaws.com` (or your CI/CD) to assume
   - Has the policy attached

3. **Role ARN Output**
   - Use this in your CI/CD configuration

## Testing the Role

### Test from Command Line

```bash
# Get role ARN
ROLE_ARN=$(terraform output -raw deployment_role_arn)

# Assume the role (if you have permissions)
aws sts assume-role \
  --role-arn "${ROLE_ARN}" \
  --role-session-name "test-session"

# This returns temporary credentials:
# {
#   "AccessKeyId": "...",
#   "SecretAccessKey": "...",
#   "SessionToken": "...",
#   "Expiration": "..."
# }
```

### Use Temporary Credentials

```bash
export AWS_ACCESS_KEY_ID="<from assume-role>"
export AWS_SECRET_ACCESS_KEY="<from assume-role>"
export AWS_SESSION_TOKEN="<from assume-role>"

# Now you can deploy
aws s3 sync ./build s3://bucket-name
```

## Summary

**For Manual Deployment (You):**
- ❌ Don't enable role
- ✅ Use AWS profile with keys
- ✅ Simple and works

**For CI/CD Automation:**
- ✅ Enable role
- ✅ Configure trust for your CI/CD provider
- ✅ Use role ARN in CI/CD config
- ✅ No keys stored in CI/CD

**You DON'T need:**
- Separate IAM users
- Manual policy creation
- Additional setup beyond Terraform

The Terraform module creates everything you need!

