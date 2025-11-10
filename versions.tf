# Terraform and provider version constraints
# This file can be used to specify version requirements

terraform {
  # Minimum Terraform version required
  required_version = ">= 1.0"

  backend "s3" {}

  # Required providers with version constraints
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

