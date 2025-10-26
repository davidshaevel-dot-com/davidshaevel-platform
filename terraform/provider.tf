# AWS Provider Configuration
# Configures the AWS provider to interact with AWS services
#
# The provider automatically uses the following environment variables:
# - AWS_REGION: The AWS region to deploy resources
# - AWS_PROFILE: The AWS CLI profile to use for authentication
#
# These are set in your .envrc file (not committed to Git)

provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources created by this provider
  # These tags help with cost tracking, ownership, and resource management
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = var.repository_name
    }
  }
}

# AWS Provider for us-east-1 (CloudFront ACM certificates)
# CloudFront requires ACM certificates to be in us-east-1 region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  # Default tags applied to all resources created by this provider
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = var.repository_name
    }
  }
}
