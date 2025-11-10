# Static Site Deployment with Terraform

Infrastructure-as-code templates for hosting static sites on AWS. Terraform creates a private S3 bucket, secures it behind CloudFront using Origin Access Control (OAC), and provides automation scripts plus CI/CD pipelines for staging and production deployments.

---

## About the Project

- **S3 + CloudFront** – private bucket for static site assets fronted by a global CDN.
- **Origin Access Control (OAC)** – only CloudFront can read from S3; no public bucket access.
- **Workspaces** – `dev`, `staging`, and `prod` environments kept isolated.
- **Automation scripts** – helper shell scripts wrap Terraform actions.
- **CI/CD ready** – GitHub Actions workflows deploy staging and production using OIDC roles.

Directory snapshot:

```
.
├── main.tf                 # Root Terraform configuration
├── variables.tf            # Shared variables
├── modules/                # Re-usable modules (s3, cloudfront, iam)
├── environments/           # Environment specific tfvars
├── backend/                # Remote state backend configs (staging/prod)
├── scripts/                # Helper scripts (init, plan, apply, destroy, etc.)
└── sample/index.html       # Tutorial landing page
```

---

## Local AWS Setup (Development)

1. **Install tools**
   - Terraform ≥ 1.0
   - AWS CLI

2. **Configure an AWS profile** (`deploy-config` is the default the scripts expect):
   ```bash
   aws configure --profile deploy-config
   aws sts get-caller-identity --profile deploy-config
   ```

3. **Clone & install dependencies**
   ```bash
git clone <repo>
cd static-site-deploy
   ```

4. **(Optional) customise `environments/dev/terraform.tfvars`** for cache TTL, naming, etc.

---

## Local Development Workflow

All commands run from the project root. The scripts automatically set the workspace, validate your AWS profile, and call `terraform init` as needed.

```bash
# Initialise Terraform (local state for dev)
./scripts/init.sh

# Create a plan
./scripts/plan.sh dev

# Apply infrastructure
./scripts/apply.sh dev

# Upload a static site build and invalidate CloudFront
./scripts/upload.sh dev ./path/to/static-site-build

# View important outputs (bucket name, CloudFront URL, etc.)
./scripts/outputs.sh dev

# Destroy dev resources when finished
./scripts/destroy.sh dev
```

> Development keeps state locally (`.terraform/terraform.tfstate.d/dev/`). Feel free to add `backend/dev.hcl` if you want dev to use remote state too.

---

## Staging & Production CI/CD

### How the pipeline works
- GitHub Actions runs on pushes to the `staging` or `main` branches.
- OIDC allows GitHub to assume a short-lived AWS IAM role (no static keys).
- Terraform uses the remote state backend (S3 + DynamoDB) to plan/apply.
- Workflow uploads the static-site bundle and invalidates CloudFront.

### Requirements
1. **Remote state bucket & lock table** – use the helper script:
   ```bash
   ./scripts/setup-remote-state.sh staging
   ./scripts/setup-remote-state.sh prod
   ```
   This creates the S3 bucket + DynamoDB table and writes `backend/<env>.hcl`.

2. **OIDC IAM role and policy** – run once per environment:
   ```bash
   ./scripts/setup-iam-oidc.sh staging <aws_account_id> <github_owner/repo>
   ./scripts/setup-iam-oidc.sh prod     <aws_account_id> <github_owner/repo>
   ```
   The script outputs role ARNs and prompts you to add GitHub secrets (`AWS_ACCOUNT_ID`, `AWS_ROLE_ARN_STAGING`, `AWS_ROLE_ARN_PROD`).

3. **Commit backend configs** – `backend/staging.hcl` and `backend/prod.hcl` must live in the repo so the workflow can read them.

4. **Review workflows** – `.github/workflows/deploy-staging.yml` and `deploy-prod.yml` run the standard Terraform sequence (`init`, `plan`, `apply`, upload build, invalidate cache).

### Triggering the pipeline
```bash
git push origin staging  # deploys staging
git push origin main     # deploys production
```

Need changes? Update Terraform files, commit, and push for the pipeline to run with the new state.

---

## State File Management

### Remote state (staging/prod)
- State is stored in S3 (`static-site-deploy/<env>/terraform.tfstate`).
- DynamoDB provides state locking to prevent concurrent operations.
- AWS S3 versioning retains history, so you can restore earlier states if needed.
- Scripts automatically detect `backend/<env>.hcl` and run `terraform init -backend-config=...`.

### Local state (dev)
- Dev defaults to local state for quick iteration.
- To convert dev to remote state, copy one of the backend templates:
  ```bash
  cp backend/staging.hcl backend/dev.hcl   # update bucket/table names
  ./scripts/init.sh dev                    # reinitialise with remote backend
  ```

### Restoring previous state
If you need to roll back:
1. Use S3 versioning to retrieve a previous `terraform.tfstate`.
2. Upload the desired version back to the S3 key.
3. Run `terraform apply` to reconcile resources with the restored state.

---

## Working Without Remote State

Prefer not to use remote state for staging/prod? You can, but it requires a few adjustments:

1. **Remove backend configs**
   - Delete `backend/staging.hcl` and `backend/prod.hcl`.
   - Edit the GitHub workflows to run plain `terraform init` (without `-backend-config`).

2. **Ensure only one runner modifies state**
   - Without DynamoDB locking, concurrent runs can corrupt state.
   - Use a single runner or manual coordination to avoid overlap.

3. **Share the state manually**
   - Commit `.terraform` state is **not** recommended (contains secrets). Instead, consider storing state in a protected artifact or a shared filesystem.

4. **Update helper scripts (optional)**
   - Scripts already fall back to local state when the backend file is missing, so no extra edits are required locally.

Remote state is strongly recommended for team workflows because it provides locking, backups, and consistency in CI/CD. Use local-only state only for simple/dev scenarios.

---

## Helpful Scripts & Docs

| Script | Purpose |
| --- | --- |
| `setup-remote-state.sh` | Creates S3 bucket + DynamoDB table, writes backend config |
| `setup-iam-oidc.sh` | Creates IAM policy + role for GitHub OIDC deployments |
| `init.sh`, `plan.sh`, `apply.sh`, `destroy.sh` | Wrap Terraform commands per environment |
| `upload.sh` | Syncs build artifacts to S3 and invalidates CloudFront |

Further reading:
- `scripts/README.md` – details for every helper script
- `WORKSPACES_GUIDE.md` – how workspaces isolate environments
- `GITHUB_ACTIONS_SETUP.md` – deeper dive into CI/CD configuration
- `IAM_ROLE_GUIDE.md` – background on IAM roles and trust policies
- `AWS_PROFILE_SETUP.md` – step-by-step for configuring AWS CLI profiles

---

## Troubleshooting Quick Reference

| Issue | Fix |
| --- | --- |
| Workspace not found | Run `./scripts/plan.sh <env>` to create it |
| Access denied to state bucket/table | Re-run `setup-iam-oidc.sh` to update policy with correct permissions |
| Destroy fails: bucket not empty | Re-run `./scripts/apply.sh` (adds `force_destroy = true`) then destroy, or manually empty bucket |
| GitHub workflow fails at init | Ensure `backend/<env>.hcl` exists with real bucket/table names |
| Need rollback | Restore previous state version from S3, then re-apply |

---

## License & Contributions

The project is provided as-is to help you deploy static sites securely to AWS. Feel free to fork and adapt to your use case.

When contributing:
1. Keep secrets out of git (`.tfvars`, real backend values, etc.).
2. Use `terraform fmt` and `terraform validate` before committing.
3. Open PRs with a clear description of infrastructure changes.

Happy deploying! 🎮🚀
