#!/bin/bash

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <environment> [--auto-approve]" >&2
  exit 1
fi

ENVIRONMENT="$1"
AUTO_FLAG="${2:-}"
AUTO_APPROVE=false

if [ "${AUTO_FLAG}" = "--auto-approve" ]; then
  AUTO_APPROVE=true
fi

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

if [ ! -d .terraform ]; then
  terraform init
fi

# Select workspace for this environment
if terraform workspace list | grep -qE "^\s*\*?\s*${ENVIRONMENT}$"; then
  echo "Selecting workspace: ${ENVIRONMENT}"
  terraform workspace select "${ENVIRONMENT}"
else
  echo "Workspace '${ENVIRONMENT}' does not exist. Nothing to destroy." >&2
  exit 1
fi

echo "Using workspace: $(terraform workspace show)"

read -p "Destroy all resources for '${ENVIRONMENT}'? type the environment name to confirm: " CONFIRM
if [ "${CONFIRM}" != "${ENVIRONMENT}" ]; then
  echo "Destruction cancelled."
  exit 0
fi

if [ "${AUTO_APPROVE}" = true ]; then
  terraform destroy -auto-approve -var-file="${VAR_FILE}"
else
  terraform destroy -var-file="${VAR_FILE}"
fi

tf_plan="tfplan-${ENVIRONMENT}.out"
if [ -f "${tf_plan}" ]; then
  rm "${tf_plan}"
fi

