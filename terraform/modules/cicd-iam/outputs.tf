# Outputs for CI/CD IAM Module

output "user_name" {
  description = "Name of the GitHub Actions IAM user"
  value       = aws_iam_user.github_actions.name
}

output "user_arn" {
  description = "ARN of the GitHub Actions IAM user"
  value       = aws_iam_user.github_actions.arn
}

output "user_unique_id" {
  description = "Unique ID of the GitHub Actions IAM user"
  value       = aws_iam_user.github_actions.unique_id
}

output "policy_arn" {
  description = "ARN of the GitHub Actions deployment policy"
  value       = aws_iam_policy.github_actions_deployment.arn
}

output "policy_name" {
  description = "Name of the GitHub Actions deployment policy"
  value       = aws_iam_policy.github_actions_deployment.name
}
