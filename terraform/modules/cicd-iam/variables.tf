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

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation permissions (optional)"
  type        = string
  default     = ""
}
