# ------------------------------------------------------------------------------
# ECR Repositories for Container Images
#
# This file creates ECR repositories for frontend and backend container images
# with image scanning, encryption, and lifecycle policies
#
# Note: These resources are conditional based on var.create_ecr_repos.
# In DR environments, ECR repos are managed separately as always-on resources
# to prevent accidental destruction during DR deactivation.
# See TT-75 for details.
# ------------------------------------------------------------------------------

# Backend ECR Repository
resource "aws_ecr_repository" "backend" {
  count = var.create_ecr_repos ? 1 : 0

  name                 = "${var.project_name}/backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-backend-ecr"
    Application = "backend"
  })
}

# Backend ECR Lifecycle Policy - Keep last 10 images
resource "aws_ecr_lifecycle_policy" "backend" {
  count = var.create_ecr_repos ? 1 : 0

  repository = aws_ecr_repository.backend[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Frontend ECR Repository
resource "aws_ecr_repository" "frontend" {
  count = var.create_ecr_repos ? 1 : 0

  name                 = "${var.project_name}/frontend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-frontend-ecr"
    Application = "frontend"
  })
}

# Frontend ECR Lifecycle Policy - Keep last 10 images
resource "aws_ecr_lifecycle_policy" "frontend" {
  count = var.create_ecr_repos ? 1 : 0

  repository = aws_ecr_repository.frontend[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Grafana ECR Repository
resource "aws_ecr_repository" "grafana" {
  count = var.create_ecr_repos ? 1 : 0

  name                 = "${var.project_name}/grafana"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-grafana-ecr"
    Application = "grafana"
  })
}

# Grafana ECR Lifecycle Policy - Keep last 10 images
resource "aws_ecr_lifecycle_policy" "grafana" {
  count = var.create_ecr_repos ? 1 : 0

  repository = aws_ecr_repository.grafana[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
