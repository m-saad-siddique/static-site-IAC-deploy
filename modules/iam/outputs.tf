# Outputs for IAM module

# Deployment policy ARN
output "deployment_policy_arn" {
  description = "ARN of the deployment IAM policy"
  value       = var.create_deployment_policy ? aws_iam_policy.deployment_policy[0].arn : null
}

# Deployment policy name
output "deployment_policy_name" {
  description = "Name of the deployment IAM policy"
  value       = var.create_deployment_policy ? aws_iam_policy.deployment_policy[0].name : null
}

# Deployment role ARN
output "deployment_role_arn" {
  description = "ARN of the deployment IAM role"
  value       = var.create_deployment_role ? aws_iam_role.deployment_role[0].arn : null
}

# Deployment role name
output "deployment_role_name" {
  description = "Name of the deployment IAM role"
  value       = var.create_deployment_role ? aws_iam_role.deployment_role[0].name : null
}

