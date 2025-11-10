# Terraform backend configuration for production environment
# Update the bucket and dynamodb_table values to match your infrastructure
bucket         = "REPLACE_ME_STATE_BUCKET"
key            = "webgl-deploy/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "REPLACE_ME_TERRAFORM_LOCKS"
encrypt        = true
