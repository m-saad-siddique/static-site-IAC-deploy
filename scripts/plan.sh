#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <environment>" >&2
  exit 1
fi

ENVIRONMENT="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAR_FILE="${PROJECT_ROOT}/environments/${ENVIRONMENT}/terraform.tfvars"
PROFILE="${AWS_PROFILE_NAME:-deploy-config}"

if [ ! -f "${VAR_FILE}" ]; then
  echo "Environment file not found: ${VAR_FILE}" >&2
  exit 1
fi

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

BACKEND_FILE="${PROJECT_ROOT}/backend/${ENVIRONMENT}.hcl"

if [ -f "${BACKEND_FILE}" ]; then
  terraform init -backend-config="${BACKEND_FILE}" -reconfigure
else
  if [ ! -d .terraform ]; then
    terraform init
  fi
fi

# Select or create workspace for this environment
if terraform workspace list | grep -qE "^\s*\*?\s*${ENVIRONMENT}$"; then
  echo "Selecting existing workspace: ${ENVIRONMENT}"
  terraform workspace select "${ENVIRONMENT}"
else
  echo "Creating new workspace: ${ENVIRONMENT}"
  terraform workspace new "${ENVIRONMENT}" || terraform workspace select "${ENVIRONMENT}"
fi

echo "Using workspace: $(terraform workspace show)"

terraform plan -var-file="${VAR_FILE}" -out="tfplan-${ENVIRONMENT}.out"

echo "Plan saved to tfplan-${ENVIRONMENT}.out"

