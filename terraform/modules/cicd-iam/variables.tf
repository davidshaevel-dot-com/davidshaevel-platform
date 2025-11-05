# Variables for CI/CD IAM Module

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "davidshaevel"
}

variable "aws_account_id" {
  description = "AWS Account ID for IAM resource ARNs"
  type        = string
}

variable "aws_region" {
  description = "AWS Region for CloudWatch Logs ARN"
  type        = string
  default     = "us-east-1"
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer for scoped ELB permissions"
  type        = string
}

variable "target_group_arns" {
  description = "List of Target Group ARNs for scoped ELB permissions"
  type        = list(string)
}
