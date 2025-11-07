# Deployment Scripts

This directory contains small helper scripts for common Terraform tasks.

## AWS Profile Requirement

All scripts expect an AWS profile named `deploy-config`. Override the profile by setting `AWS_PROFILE_NAME` before running a script.

See the main [README.md](../README.md) for details on creating the profile.

## Available Scripts

### `init.sh`
Initialise Terraform (safe to rerun).

```bash
./scripts/init.sh
```

### `plan.sh`
Generate a plan for an environment (plan file saved as `tfplan-<env>.out`).

```bash
./scripts/plan.sh dev
```

### `apply.sh`
Apply changes for an environment. Accepts `--auto-approve`.

```bash
./scripts/apply.sh dev [--auto-approve]
```

### `destroy.sh`
Destroy all resources for an environment. Prompts for confirmation. Supports `--auto-approve`.

```bash
./scripts/destroy.sh dev [--auto-approve]
```

### `outputs.sh`
Print Terraform outputs for an environment.

```bash
./scripts/outputs.sh dev
```

### `upload.sh`
Sync a local directory (your WebGL build) into the environment's S3 bucket, then trigger a CloudFront invalidation.

```bash
./scripts/upload.sh dev path/to/build [subfolder]
```

## Quick Start

```bash
./scripts/init.sh
./scripts/plan.sh dev
./scripts/apply.sh dev
```

## What Each Script Checks

- Terraform CLI is installed
- AWS CLI is installed
- The requested environment file exists
- The AWS profile is configured; `AWS_PROFILE_NAME` can override the default
- `terraform init` runs automatically when needed

## Notes

- Run scripts from anywhere; they switch into the project root automatically
- `apply.sh` asks for confirmation before touching `prod` unless `--auto-approve` is used
- `destroy.sh` always asks you to retype the environment name
- Plan files are reused automatically if present

