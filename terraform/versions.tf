# Terraform and Provider Version Constraints
# This file specifies the required Terraform version and provider versions
# to ensure compatibility and prevent unexpected behavior from version changes.

terraform {
  # Require Terraform version 1.13.4 or higher (latest stable as of Oct 2025)
  # Using >= allows for future updates while maintaining compatibility
  required_version = ">= 1.13.4"

  required_providers {
    # AWS Provider v6.18.0 (latest stable as of Oct 23, 2025)
    # Official provider for Amazon Web Services
    # Documentation: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    # Changelog: https://github.com/hashicorp/terraform-provider-aws/releases
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18"
    }
  }
}
