# Git Setup Guide

## Before Pushing to GitHub

### 1. Review Your .gitignore

The `.gitignore` file is configured to exclude:
- ✅ Terraform state files (`*.tfstate`)
- ✅ Plan files (`tfplan-*.out`)
- ✅ Sensitive `.tfvars` files (but `terraform.tfvars.example` is included)
- ✅ AWS credentials
- ✅ IDE files
- ✅ Temporary files

### 2. Check for Sensitive Data

**⚠️ IMPORTANT:** Before pushing, ensure you haven't committed:

- Real AWS Account IDs in `environments/*/terraform.tfvars`
- Real GitHub repository names with actual credentials
- AWS access keys or secrets
- Terraform state files (contain sensitive data)

### 3. Update Placeholder Values

The `environments/*/terraform.tfvars` files contain placeholders:
- `YOUR_AWS_ACCOUNT_ID` - Replace with your actual account ID
- `YOUR_GITHUB_USERNAME/YOUR_REPO` - Replace with your repository

**Option A: Keep placeholders (Recommended)**
- Commit the files with placeholders
- Team members fill in their own values
- Safe to share publicly

**Option B: Use environment variables**
- Don't commit `.tfvars` files
- Use `terraform.tfvars.example` as template
- Each developer creates their own `.tfvars` locally

### 4. Files That Should Be Committed

✅ **Safe to commit:**
- All `.tf` files (Terraform code)
- `terraform.tfvars.example` (template)
- `scripts/` (deployment scripts)
- `modules/` (Terraform modules)
- `sample/` (sample files)
- Documentation (`.md` files)
- `.gitignore`
- `.gitattributes`

❌ **Should NOT be committed:**
- `*.tfstate` files
- `*.tfstate.backup` files
- `tfplan-*.out` files
- Actual `.tfvars` files with real values (if they contain secrets)
- `.terraform/` directories
- AWS credentials

### 5. Initial Commit Checklist

```bash
# 1. Check what will be committed
git status

# 2. Verify no sensitive files
git diff --cached

# 3. If you see terraform.tfstate or tfplan files, remove them:
git rm --cached terraform.tfstate terraform.tfstate.backup tfplan-*.out

# 4. Commit
git add .
git commit -m "Initial commit: WebGL deployment infrastructure"

# 5. Push to GitHub
git remote add origin https://github.com/your-username/your-repo.git
git push -u origin main
```

### 6. After Pushing

**For team members:**
1. Clone the repository
2. Copy `terraform.tfvars.example` to create their own `.tfvars` files
3. Fill in their AWS Account ID and repository details
4. Run `./scripts/init.sh` and deploy

**For CI/CD:**
- Configure GitHub Actions using the role ARN from Terraform outputs
- See `GITHUB_ACTIONS_SETUP.md` for details

## Security Best Practices

1. **Never commit:**
   - AWS access keys
   - Secret keys
   - Terraform state files
   - Real account IDs (use placeholders)

2. **Use placeholders:**
   - `YOUR_AWS_ACCOUNT_ID` instead of real IDs
   - `YOUR_GITHUB_USERNAME/YOUR_REPO` instead of real repos

3. **Review before pushing:**
   ```bash
   git log --all --full-history --source -- "*tfvars*"
   ```

4. **If you accidentally committed secrets:**
   - Rotate the credentials immediately
   - Use `git filter-branch` or BFG Repo-Cleaner to remove from history
   - Force push (coordinate with team first)

## Repository Structure

```
webgl-deploy/
├── .gitignore          ✅ Committed
├── .gitattributes      ✅ Committed
├── main.tf             ✅ Committed
├── variables.tf         ✅ Committed
├── outputs.tf          ✅ Committed
├── versions.tf         ✅ Committed
├── terraform.tfvars.example  ✅ Committed (template)
├── environments/
│   ├── dev/
│   │   └── terraform.tfvars  ⚠️ Review before committing
│   ├── staging/
│   │   └── terraform.tfvars  ⚠️ Review before committing
│   └── prod/
│       └── terraform.tfvars  ⚠️ Review before committing
├── modules/            ✅ Committed
├── scripts/            ✅ Committed
└── sample/             ✅ Committed
```

## Quick Start for New Team Members

```bash
# 1. Clone repository
git clone https://github.com/your-org/webgl-deploy.git
cd webgl-deploy

# 2. Create your own tfvars (not committed)
cp terraform.tfvars.example environments/dev/terraform.tfvars

# 3. Edit with your values
# 4. Deploy
./scripts/init.sh
./scripts/plan.sh dev
./scripts/apply.sh dev
```

