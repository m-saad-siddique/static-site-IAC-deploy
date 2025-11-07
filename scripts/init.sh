#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${AWS_PROFILE_NAME:-deploy-config}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "Terraform is not installed. Please install Terraform and try again." >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is not installed. Please install AWS CLI and try again." >&2
  exit 1
fi

if ! aws configure list-profiles 2>/dev/null | grep -qx "${PROFILE}"; then
  echo "AWS profile '${PROFILE}' is not configured. Run 'aws configure --profile ${PROFILE}' first." >&2
  exit 1
fi

export AWS_PROFILE="${PROFILE}"

cd "${PROJECT_ROOT}"

# Initialize Terraform
terraform init

# Show current workspace
echo ""
echo "Current workspace: $(terraform workspace show)"
echo ""
echo "Available workspaces:"
terraform workspace list
echo ""
echo "To switch workspace: terraform workspace select <environment>"

