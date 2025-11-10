# Terraform backend configuration for staging environment
# Update the bucket and dynamodb_table values to match your infrastructure
bucket         = "REPLACE_ME_STATE_BUCKET"
key            = "webgl-deploy/staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "REPLACE_ME_TERRAFORM_LOCKS"
encrypt        = true
