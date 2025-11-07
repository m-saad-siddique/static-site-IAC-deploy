#!/bin/bash

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <environment> <local_directory> [s3_subpath]" >&2
  exit 1
fi

env_name="$1"
local_dir="$2"
s3_subpath="${3:-}"

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
var_file="${project_root}/environments/${env_name}/terraform.tfvars"
profile="${AWS_PROFILE_NAME:-deploy-config}"

if [ ! -d "${local_dir}" ]; then
  echo "Local directory not found: ${local_dir}" >&2
  exit 1
fi

if [ ! -f "${var_file}" ]; then
  echo "Environment file not found: ${var_file}" >&2
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

if ! aws configure list-profiles 2>/dev/null | grep -qx "${profile}"; then
  echo "AWS profile '${profile}' is not configured. Run 'aws configure --profile ${profile}' first." >&2
  exit 1
fi

export AWS_PROFILE="${profile}"

cd "${project_root}"

if [ ! -d .terraform ]; then
  terraform init >/dev/null
fi

bucket_name=$(terraform output -raw s3_bucket_id 2>/dev/null || true)
if [ -z "${bucket_name}" ]; then
  echo "Unable to determine S3 bucket name from Terraform state." >&2
  echo "Make sure 'terraform apply' has been run for ${env_name} and that you are in the same working directory." >&2
  exit 1
fi

destination="s3://${bucket_name}"

echo "Syncing '${local_dir}' to '${destination}' using profile '${profile}'..."
aws s3 sync "${local_dir}" "${destination}" --delete

echo "Upload complete."

distribution_id=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || true)
if [ -n "${distribution_id}" ]; then
  echo "Creating CloudFront invalidation for distribution ${distribution_id}..."
  aws cloudfront create-invalidation \
    --distribution-id "${distribution_id}" \
    --paths "/*"
  echo "Invalidation request submitted."
else
  echo "Warning: unable to determine CloudFront distribution ID; skipping invalidation." >&2
fi
