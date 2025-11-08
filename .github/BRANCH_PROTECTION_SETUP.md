# GitHub Branch Protection Setup Guide

## Overview

This guide explains how to set up branch protection rules in GitHub to enforce the deployment workflow.

## Required GitHub Secrets

Before workflows can run, you need to add these secrets in GitHub:

1. Go to **Repository Settings → Secrets and variables → Actions**
2. Add the following secrets:

### AWS Role ARNs

Get the role ARNs from Terraform outputs:

```bash
# Dev role ARN
./scripts/outputs.sh dev | grep deployment_role_arn

# Staging role ARN
./scripts/outputs.sh staging | grep deployment_role_arn

# Prod role ARN
./scripts/outputs.sh prod | grep deployment_role_arn
```

Then add to GitHub Secrets:
- `AWS_ROLE_ARN_DEV` = `arn:aws:iam::ACCOUNT:role/webgl-dev-deployment-role`
- `AWS_ROLE_ARN_STAGING` = `arn:aws:iam::ACCOUNT:role/webgl-staging-deployment-role`
- `AWS_ROLE_ARN_PROD` = `arn:aws:iam::ACCOUNT:role/webgl-prod-deployment-role`

## Branch Protection Rules

### 1. Protect Main Branch

**Settings → Branches → Add rule**

- **Branch name pattern:** `main`
- **Protect matching branches:**
  - ✅ Require a pull request before merging
    - Required approvals: 1 (optional but recommended)
    - Dismiss stale pull request approvals when new commits are pushed
  - ✅ Require status checks to pass before merging
    - Require branches to be up to date before merging
  - ✅ Require conversation resolution before merging
  - ✅ Do not allow bypassing the above settings
    - ✅ Include administrators
  - ✅ Restrict pushes that create files matching `**`
  - ✅ Do not allow deleting this branch

### 2. Protect Staging Branch

**Settings → Branches → Add rule**

- **Branch name pattern:** `staging`
- **Protect matching branches:**
  - ✅ Require a pull request before merging
    - Require branches to be up to date before merging
  - ✅ Do not allow bypassing the above settings
    - ✅ Include administrators
  - ✅ Restrict pushes that create files matching `**`
  - ✅ Do not allow deleting this branch

### 3. Protect Dev Branch

**Settings → Branches → Add rule**

- **Branch name pattern:** `dev`
- **Protect matching branches:**
  - ✅ Do not allow deleting this branch
  - ❌ Allow direct pushes (dev is for active development)

## GitHub Environment (Optional but Recommended)

For production deployments, set up a GitHub Environment with manual approval:

1. **Settings → Environments → New environment**
2. **Name:** `production`
3. **Protection rules:**
   - ✅ Required reviewers: Add team members who can approve
   - ✅ Wait timer: 0 minutes (or set delay if needed)
4. **Save**

This adds a manual approval step before production deployments.

## Workflow Summary

### Allowed Workflow:
```
Feature Branch → PR to dev → Merge
              ↓
           dev → PR to staging → Auto-deploy staging
              ↓
        staging → PR to main → Manual approval → Auto-deploy prod
```

### Blocked Actions:
- ❌ Direct push to staging
- ❌ Direct push to main
- ❌ PR from feature branch to staging
- ❌ PR from feature branch to main
- ❌ PR from dev to main (must go through staging)
- ❌ Delete dev/staging/main branches

## Testing the Setup

1. **Test branch protection:**
   - Try to push directly to staging → Should be blocked
   - Try to create PR from feature branch to main → Should be blocked by workflow

2. **Test workflows:**
   - Push to dev → Dev workflow runs
   - Merge dev to staging → Staging workflow runs
   - Merge staging to main → Prod workflow runs (with approval if configured)

## Troubleshooting

### Workflow fails with "Role not found"
- Verify IAM roles are created: `./scripts/outputs.sh <env>`
- Check GitHub Secrets are set correctly
- Verify OIDC is configured in Terraform

### Branch protection not working
- Check branch protection rules are enabled
- Verify "Include administrators" is checked
- Check workflow has correct permissions

### PR validation fails
- Review the PR comment for specific error
- Follow the suggested workflow
- Ensure you're merging from correct source branch

