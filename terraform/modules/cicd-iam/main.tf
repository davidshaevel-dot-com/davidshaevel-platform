# CI/CD IAM Module
# Creates IAM user and policy for GitHub Actions deployments to ECS

terraform {
  required_version = ">= 1.5.0"
}

# IAM User for GitHub Actions
resource "aws_iam_user" "github_actions" {
  name = "${var.environment}-${var.project_name}-github-actions"
  path = "/cicd/"

  tags = {
    Name        = "${var.environment}-${var.project_name}-github-actions"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Purpose     = "GitHub Actions CI/CD deployments"
  }
}

# IAM Policy for GitHub Actions with minimal required permissions
resource "aws_iam_policy" "github_actions_deployment" {
  name        = "${var.environment}-${var.project_name}-github-actions-deployment"
  path        = "/cicd/"
  description = "Minimal permissions for GitHub Actions to deploy to ECS Fargate"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthAndPush"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSTaskDefinitionManagement"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMPassRoleForECS"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-${var.project_name}-ecs-task-execution-role",
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-${var.project_name}-backend-task-role",
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-${var.project_name}-frontend-task-role"
        ]
      },
      {
        Sid    = "CloudWatchLogsForDeployment"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/${var.project_name}/*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-${var.project_name}-github-actions-deployment"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "github_actions_deployment" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.github_actions_deployment.arn
}
