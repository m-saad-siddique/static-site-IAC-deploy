# Environment Configuration Guide

## Overview

This project supports three environments:
- **dev** – Local state, manual deployments with the `deploy-config` AWS profile.
- **staging** – Remote state + GitHub Actions OIDC (IAM role created by helper script).
- **prod** – Remote state + GitHub Actions OIDC (IAM role created by helper script).

## One-Time Setup for Staging & Production

1. **Gather account details**
   ```bash
   AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   ```

2. **Create remote state resources** (S3 bucket + DynamoDB table)
   ```bash
   aws s3api create-bucket --bucket <state-bucket-name> --region us-east-1
   aws dynamodb create-table \
     --table-name <lock-table-name> \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

3. **Update backend configuration files**
   - `backend/staging.hcl`
   - `backend/prod.hcl`

   Set the `bucket`, `key`, `region`, and `dynamodb_table` values to match the resources you just created. Keep `encrypt = true`.

4. **Create IAM role & policy for GitHub Actions**
   ```bash
   ./scripts/setup-iam-oidc.sh staging $AWS_ACCOUNT_ID <github_owner/repo>
   ./scripts/setup-iam-oidc.sh prod     $AWS_ACCOUNT_ID <github_owner/repo>
   ```

   The script outputs the role ARN for each environment. Add the following GitHub secrets:
   - `AWS_ACCOUNT_ID`
   - `AWS_ROLE_ARN_STAGING`
   - `AWS_ROLE_ARN_PROD`

5. **Deploy infrastructure**
   ```bash
   ./scripts/plan.sh staging
   ./scripts/apply.sh staging

   ./scripts/plan.sh prod
   ./scripts/apply.sh prod
   ```

6. **Optional:** Tighten IAM policy ARNs after deployment
   ```bash
   ./scripts/update-iam-policy.sh staging
   ./scripts/update-iam-policy.sh prod
   ```

## GitHub Actions Workflow Example

See `GITHUB_ACTIONS_SETUP.md` for complete workflow examples.

## Notes

- **Dev environment**: Local state only, IAM role not required.
- **Staging/Prod**: Remote state + IAM role via `scripts/setup-iam-oidc.sh`.
- Remote state files live in S3 with locking handled by DynamoDB.

