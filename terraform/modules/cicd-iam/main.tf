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
      # ECR: GetAuthorizationToken must use "*" (AWS requirement)
      {
        Sid      = "ECRGetAuthorizationToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      # ECR: Repository-specific actions scoped to our repositories
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project_name}/backend",
          "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project_name}/frontend"
        ]
      },
      # ECS: Task definition operations must use "*" (ARNs unknown before creation)
      {
        Sid    = "ECSTaskDefinitionOperations"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      # ECS: Service operations scoped to specific services
      {
        Sid    = "ECSServiceOperations"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${var.environment}-${var.project_name}-cluster/${var.environment}-${var.project_name}-backend",
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${var.environment}-${var.project_name}-cluster/${var.environment}-${var.project_name}-frontend"
        ]
      },
      # ECS: Task operations with cluster condition
      {
        Sid    = "ECSTaskOperations"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ecs:cluster" = "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:cluster/${var.environment}-${var.project_name}-cluster"
          }
        }
      },
      # IAM: PassRole scoped to specific ECS task roles
      {
        Sid    = "IAMPassRoleForECS"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-${var.project_name}-ecs-task-execution-role",
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-${var.project_name}-backend-task-role",
          "arn:aws:iam::${var.aws_account_id}:role/${var.environment}-${var.project_name}-frontend-task-role"
        ]
      },
      # CloudWatch Logs: Scoped to ECS log groups
      {
        Sid    = "CloudWatchLogsForDeployment"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/${var.environment}-${var.project_name}/*",
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/${var.environment}-${var.project_name}/*:*"
        ]
      },
      # ELB: Read-only permissions to retrieve service URLs for deployment reporting
      {
        Sid    = "ELBReadOnlyForServiceURL"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = "*"
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
