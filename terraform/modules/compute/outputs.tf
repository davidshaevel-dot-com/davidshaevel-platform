# ------------------------------------------------------------------------------
# Compute Module Outputs
# ECS Fargate cluster, ALB, and service information
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ECS Cluster Outputs
# ------------------------------------------------------------------------------

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

# ------------------------------------------------------------------------------
# Application Load Balancer Outputs
# ------------------------------------------------------------------------------

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn_suffix" {
  description = "ARN suffix for use with CloudWatch Metrics"
  value       = aws_lb.main.arn_suffix
}

# ------------------------------------------------------------------------------
# Target Group Outputs
# ------------------------------------------------------------------------------

output "frontend_target_group_id" {
  description = "ID of the frontend target group"
  value       = aws_lb_target_group.frontend.id
}

output "frontend_target_group_arn" {
  description = "ARN of the frontend target group"
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_id" {
  description = "ID of the backend target group"
  value       = aws_lb_target_group.backend.id
}

output "backend_target_group_arn" {
  description = "ARN of the backend target group"
  value       = aws_lb_target_group.backend.arn
}

# ------------------------------------------------------------------------------
# ECS Service Outputs
# ------------------------------------------------------------------------------

output "frontend_service_id" {
  description = "ID of the frontend ECS service"
  value       = aws_ecs_service.frontend.id
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = aws_ecs_service.frontend.name
}

output "backend_service_id" {
  description = "ID of the backend ECS service"
  value       = aws_ecs_service.backend.id
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = aws_ecs_service.backend.name
}

# ------------------------------------------------------------------------------
# Task Definition Outputs
# ------------------------------------------------------------------------------

output "frontend_task_definition_arn" {
  description = "ARN of the frontend task definition"
  value       = aws_ecs_task_definition.frontend.arn
}

output "frontend_task_definition_family" {
  description = "Family of the frontend task definition"
  value       = aws_ecs_task_definition.frontend.family
}

output "backend_task_definition_arn" {
  description = "ARN of the backend task definition"
  value       = aws_ecs_task_definition.backend.arn
}

output "backend_task_definition_family" {
  description = "Family of the backend task definition"
  value       = aws_ecs_task_definition.backend.family
}

# ------------------------------------------------------------------------------
# ALB Listener Outputs
# ------------------------------------------------------------------------------

output "alb_http_listener_arn" {
  description = "ARN of the ALB HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "alb_https_listener_arn" {
  description = "ARN of the ALB HTTPS listener"
  value       = var.alb_certificate_arn != null ? aws_lb_listener.https[0].arn : null
}

# ------------------------------------------------------------------------------
# IAM Role Outputs
# ------------------------------------------------------------------------------

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.task_execution.arn
}

output "task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.task_execution.name
}

output "frontend_task_role_arn" {
  description = "ARN of the frontend task role"
  value       = aws_iam_role.frontend_task.arn
}

output "backend_task_role_arn" {
  description = "ARN of the backend task role"
  value       = aws_iam_role.backend_task.arn
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group Outputs
# ------------------------------------------------------------------------------

output "frontend_log_group_name" {
  description = "Name of the frontend CloudWatch log group"
  value       = aws_cloudwatch_log_group.frontend.name
}

output "backend_log_group_name" {
  description = "Name of the backend CloudWatch log group"
  value       = aws_cloudwatch_log_group.backend.name
}

# ------------------------------------------------------------------------------
# ECR Repository Outputs
# ------------------------------------------------------------------------------

output "backend_ecr_repository_url" {
  description = "URL of the backend ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "backend_ecr_repository_arn" {
  description = "ARN of the backend ECR repository"
  value       = aws_ecr_repository.backend.arn
}

output "backend_ecr_repository_name" {
  description = "Name of the backend ECR repository"
  value       = aws_ecr_repository.backend.name
}

output "frontend_ecr_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "frontend_ecr_repository_arn" {
  description = "ARN of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.arn
}

output "frontend_ecr_repository_name" {
  description = "Name of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.name
}

output "grafana_ecr_repository_url" {
  description = "URL of the Grafana ECR repository"
  value       = aws_ecr_repository.grafana.repository_url
}

output "grafana_ecr_repository_arn" {
  description = "ARN of the Grafana ECR repository"
  value       = aws_ecr_repository.grafana.arn
}

output "grafana_ecr_repository_name" {
  description = "Name of the Grafana ECR repository"
  value       = aws_ecr_repository.grafana.name
}

# ------------------------------------------------------------------------------
# Application URLs (for reference)
# ------------------------------------------------------------------------------

output "application_url" {
  description = "URL to access the application via ALB (HTTP)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "frontend_url" {
  description = "URL to access the frontend via ALB"
  value       = "http://${aws_lb.main.dns_name}"
}

output "backend_url" {
  description = "URL to access the backend API via ALB"
  value       = "http://${aws_lb.main.dns_name}/api"
}

# ------------------------------------------------------------------------------
# Container Port Outputs
# ------------------------------------------------------------------------------

output "frontend_port" {
  description = "Port number for frontend container"
  value       = local.frontend_port
}

output "backend_port" {
  description = "Port number for backend container"
  value       = local.backend_port
}
