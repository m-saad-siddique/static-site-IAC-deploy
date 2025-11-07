# Quick Start Guide

## Step 1: Initialize Terraform

```bash
terraform init
```

## Step 2: Review the Plan

For development environment:
```bash
terraform plan -var-file=environments/dev/terraform.tfvars
```

## Step 3: Apply the Configuration

For development environment:
```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

This will create:
- S3 bucket (private, not publicly accessible)
- CloudFront distribution (with OAC)
- Optional IAM resources

## Step 4: Get the Outputs

After deployment, get the CloudFront URL:
```bash
terraform output cloudfront_distribution_domain_name
```

Or get the full deployment URL:
```bash
terraform output deployment_url
```

## Step 5: Upload Your WebGL Build

Get the S3 bucket name:
```bash
BUCKET_NAME=$(terraform output -raw s3_bucket_id)
```

Upload your build files:
```bash
aws s3 sync ./WebGLBuild s3://$BUCKET_NAME/ --delete
```

## Step 6: Access Your Application

Use the CloudFront URL from Step 4 to access your WebGL application.

## Notes

- CloudFront distributions take 15-20 minutes to deploy
- The S3 bucket is private and only accessible via CloudFront
- All HTTP traffic is automatically redirected to HTTPS

