# GitHub Workflows

This directory contains CI/CD workflows for automated deployment.

## Workflows

### 1. `deploy-dev.yml`
- **Trigger:** Push to `dev` branch
- **Action:** Deploys to dev environment
- **Auto-approve:** Yes

### 2. `deploy-staging.yml`
- **Trigger:** Push to `staging` branch
- **Action:** Deploys to staging environment
- **Auto-approve:** Yes

### 3. `deploy-prod.yml`
- **Trigger:** Push to `main` branch
- **Action:** Deploys to production environment
- **Auto-approve:** Yes (but can add manual approval via GitHub Environment)

### 4. `branch-protection.yml`
- **Trigger:** Pull requests to `staging` or `main`
- **Action:** Validates branch protection rules
- **Purpose:** Enforces workflow (dev → staging → main)

## Setup Required

1. **Configure GitHub Secrets:**
   - `AWS_ROLE_ARN_DEV`
   - `AWS_ROLE_ARN_STAGING`
   - `AWS_ROLE_ARN_PROD`

2. **Set up Branch Protection Rules** (see `BRANCH_PROTECTION_SETUP.md`)

3. **Configure GitHub Environment** (optional, for prod approval)

## Workflow

```
Feature Branch → PR to dev → Merge → Auto-deploy dev
              ↓
           dev → PR to staging → Merge → Auto-deploy staging
              ↓
        staging → PR to main → (Approval) → Auto-deploy prod
```

See [BRANCH_PROTECTION_SETUP.md](BRANCH_PROTECTION_SETUP.md) for detailed setup instructions.

