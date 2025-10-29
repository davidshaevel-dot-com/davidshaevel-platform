# ------------------------------------------------------------------------------
# Compute Module - ECS Fargate and Application Load Balancer
#
# This module creates:
# - ECS Fargate cluster with Container Insights
# - Application Load Balancer (ALB) with target groups
# - ECS task definitions for frontend and backend
# - ECS services with auto-scaling configuration
# - IAM roles for task execution and application permissions
# - CloudWatch log groups for container logs
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18.0"
    }
  }
}

# ------------------------------------------------------------------------------
# Local Variables
# ------------------------------------------------------------------------------

locals {
  resource_prefix = "${var.environment}-${var.project_name}"

  # Container ports
  frontend_port = 3000
  backend_port  = 3001

  # Common tags for all resources
  common_tags = merge(var.common_tags, {
    Module = "compute"
  })
}

# ------------------------------------------------------------------------------
# ECS Cluster (Step 8)
# ------------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${local.resource_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-ecs-cluster"
  })
}

# Cluster capacity providers for Fargate
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Groups
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${local.resource_prefix}/frontend"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-frontend-logs"
    Application = "frontend"
  })
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.resource_prefix}/backend"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-backend-logs"
    Application = "backend"
  })
}

# ------------------------------------------------------------------------------
# IAM Roles - Task Execution Role
# Allows ECS to pull images and write logs
# ------------------------------------------------------------------------------

resource "aws_iam_role" "task_execution" {
  name = "${local.resource_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-ecs-task-execution-role"
  })
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager access (for database credentials)
resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${local.resource_prefix}-ecs-task-execution-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.database_secret_arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# IAM Roles - Task Roles (Application Permissions)
# ------------------------------------------------------------------------------

# Frontend task role
resource "aws_iam_role" "frontend_task" {
  name = "${local.resource_prefix}-frontend-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-frontend-task-role"
    Application = "frontend"
  })
}

# Backend task role
resource "aws_iam_role" "backend_task" {
  name = "${local.resource_prefix}-backend-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-backend-task-role"
    Application = "backend"
  })
}

# Note: Backend task role has no additional policies by default.
# Database credentials are injected as environment variables by the task execution role.
# Add application-specific permissions here as needed (e.g., S3, DynamoDB, etc.)

# ------------------------------------------------------------------------------
# Application Load Balancer (Step 8)
# ------------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${local.resource_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.alb_idle_timeout

  # Access logs (optional)
  dynamic "access_logs" {
    for_each = var.enable_alb_access_logs ? [1] : []
    content {
      bucket  = var.alb_access_logs_bucket
      enabled = true
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-alb"
  })
}

# ------------------------------------------------------------------------------
# Target Groups (Step 8)
# ------------------------------------------------------------------------------

# Frontend target group
resource "aws_lb_target_group" "frontend" {
  name        = "${local.resource_prefix}-frontend-tg"
  port        = local.frontend_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.frontend_health_check_path
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-frontend-tg"
    Application = "frontend"
  })
}

# Backend target group
resource "aws_lb_target_group" "backend" {
  name        = "${local.resource_prefix}-backend-tg"
  port        = local.backend_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.backend_health_check_path
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-backend-tg"
    Application = "backend"
  })
}

# ------------------------------------------------------------------------------
# ALB Listeners (Step 8)
# ------------------------------------------------------------------------------

# HTTPS listener (optional - only created if certificate ARN is provided)
resource "aws_lb_listener" "https" {
  count = var.alb_certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-alb-https-listener"
  })
}

# HTTP listener - redirects to HTTPS if certificate is provided, otherwise forwards
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.alb_certificate_arn != null ? "redirect" : "forward"

    # Forward to frontend if no certificate
    target_group_arn = var.alb_certificate_arn != null ? null : aws_lb_target_group.frontend.arn

    # Redirect to HTTPS if certificate is provided
    dynamic "redirect" {
      for_each = var.alb_certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-alb-http-listener"
  })
}

# Listener rule for backend API (/api/* -> backend)
# Attaches to HTTPS listener if available, otherwise HTTP
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = var.alb_certificate_arn != null ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-backend-api-rule"
  })
}

# ------------------------------------------------------------------------------
# ECS Task Definitions (Step 9)
# ------------------------------------------------------------------------------

# Frontend task definition
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.resource_prefix}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.frontend_task_cpu
  memory                   = var.frontend_task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.frontend_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true

      portMappings = [
        {
          containerPort = local.frontend_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "BACKEND_URL"
          value = "http://${aws_lb.main.dns_name}/api"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "frontend"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${local.frontend_port}/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-frontend-task"
    Application = "frontend"
  })
}

# Backend task definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.resource_prefix}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.backend_task_cpu
  memory                   = var.backend_task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.backend_task.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      essential = true

      portMappings = [
        {
          containerPort = local.backend_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production" # Always use production for deployed backend (enables SSL for RDS)
        },
        {
          name  = "DB_HOST"
          value = split(":", var.database_endpoint)[0]
        },
        {
          name  = "DB_PORT"
          value = tostring(var.database_port)
        },
        {
          name  = "DB_NAME"
          value = var.database_name
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.database_secret_arn}:password::"
        },
        {
          name      = "DB_USERNAME"
          valueFrom = "${var.database_secret_arn}:username::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "backend"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "node -e \"require('http').get('http://localhost:${local.backend_port}/api/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))\""
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-backend-task"
    Application = "backend"
  })
}

# ------------------------------------------------------------------------------
# ECS Services (Step 9)
# ------------------------------------------------------------------------------

# Frontend service
resource "aws_ecs_service" "frontend" {
  name            = "${local.resource_prefix}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.desired_count_frontend
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.frontend_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = local.frontend_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  # Ensure target group is created before service
  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.frontend
  ]

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-frontend-service"
    Application = "frontend"
  })
}

# Backend service
resource "aws_ecs_service" "backend" {
  name            = "${local.resource_prefix}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count_backend
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.backend_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = local.backend_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  # Ensure target group is created before service
  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.backend
  ]

  tags = merge(local.common_tags, {
    Name        = "${local.resource_prefix}-backend-service"
    Application = "backend"
  })
}

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------

data "aws_region" "current" {}
