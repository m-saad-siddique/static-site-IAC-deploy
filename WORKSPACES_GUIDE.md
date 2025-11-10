# Terraform Workspaces Guide

## Why Workspaces?

Terraform workspaces allow you to manage multiple environments (dev, staging, prod) **independently** with separate state files. This means:

✅ **Separate state files** - Each environment has its own state  
✅ **Independent operations** - Deploy/destroy one without affecting others  
✅ **No conflicts** - Resources are isolated per environment  
✅ **Safe destroy** - Destroying staging won't touch production  

## How It Works

Each environment maps to a dedicated workspace and backend:
- **dev** → local state (`.terraform/terraform.tfstate.d/dev/`)
- **staging** → remote S3 state defined in `backend/staging.hcl`
- **prod** → remote S3 state defined in `backend/prod.hcl`

## Usage

### Automatic Workspace Management

All scripts automatically handle workspaces:

```bash
# Deploy dev
./scripts/plan.sh dev      # Creates/selects 'dev' workspace
./scripts/apply.sh dev      # Uses 'dev' workspace

# Deploy staging
./scripts/plan.sh staging   # Creates/selects 'staging' workspace
./scripts/apply.sh staging  # Uses 'staging' workspace

# Deploy prod
./scripts/plan.sh prod      # Creates/selects 'prod' workspace
./scripts/apply.sh prod     # Uses 'prod' workspace
```

### Manual Workspace Management

You can also manage workspaces manually:

```bash
# List all workspaces
terraform workspace list

# Show current workspace
terraform workspace show

# Create new workspace
terraform workspace new staging

# Select workspace
terraform workspace select staging

# Delete workspace (after destroying resources)
terraform workspace delete staging
```

## Deployment Workflow

### Deploy All Environments

```bash
# 1. Deploy dev
./scripts/init.sh
./scripts/plan.sh dev
./scripts/apply.sh dev

# 2. Deploy staging
./scripts/plan.sh staging
./scripts/apply.sh staging

# 3. Deploy prod
./scripts/plan.sh prod
./scripts/apply.sh prod
```

Each environment is completely independent!

### Destroy Specific Environment

```bash
# Destroy only staging (prod and dev remain untouched)
./scripts/destroy.sh staging

# Destroy only dev
./scripts/destroy.sh dev

# Destroy only prod (with extra confirmation)
./scripts/destroy.sh prod
```

## State Storage Locations

- **dev** → Local file: `.terraform/terraform.tfstate.d/dev/terraform.tfstate`
- **staging** → Remote S3 object: `s3://<state-bucket>/static-site-deploy/staging/terraform.tfstate`
- **prod** → Remote S3 object: `s3://<state-bucket>/static-site-deploy/prod/terraform.tfstate`

Remote backends also use DynamoDB for state locking (see `backend/*.hcl`).

## Benefits

### Before Workspaces (Single State)
- ❌ All environments in one state file
- ❌ Risk of destroying wrong environment
- ❌ Can't manage environments independently
- ❌ State conflicts between environments

### With Workspaces (Separate States)
- ✅ Each environment isolated
- ✅ Safe to destroy any environment
- ✅ Independent management
- ✅ No conflicts

## Example: Deploy and Destroy

```bash
# Deploy staging
./scripts/apply.sh staging
# Creates: S3 bucket + CloudFront (IAM role provided separately by setup script)

# Deploy prod
./scripts/apply.sh prod
# Creates: Different S3 bucket + CloudFront (IAM role provided separately by setup script)

# Check what's deployed
terraform workspace select staging
terraform state list  # Shows staging resources

terraform workspace select prod
terraform state list  # Shows prod resources

# Destroy staging only
./scripts/destroy.sh staging
# Only staging resources destroyed, prod remains untouched
```

## Important Notes

1. **Workspace is created automatically** - First time you run `plan.sh` or `apply.sh` for an environment, the workspace is created

2. **State backend depends on environment** - dev uses local files, staging/prod use S3 (configured in `backend/<env>.hcl`)

3. **Each workspace is independent** - Resources in different workspaces don't conflict, even if they have similar names

4. **Destroy is safe** - Destroying one workspace only affects that environment's resources

## Troubleshooting

### Workspace doesn't exist
```bash
# Error: Workspace 'staging' does not exist
# Solution: Run plan or apply first (creates workspace automatically)
./scripts/plan.sh staging
```

### Wrong workspace selected
```bash
# Check current workspace
terraform workspace show

# Switch to correct workspace
terraform workspace select staging
```

### List all resources in workspace
```bash
terraform workspace select staging
terraform state list
```

## Summary

✅ **Workspaces are automatic** - Scripts handle everything  
✅ **Each environment isolated** - Safe to manage independently  
✅ **Destroy is safe** - Only affects selected environment  
✅ **No manual setup needed** - Just use the scripts as normal  

The scripts automatically create and select the correct workspace for each environment!

