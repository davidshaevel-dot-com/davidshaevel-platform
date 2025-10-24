# Terraform Remote State Backend Configuration
# Stores Terraform state in AWS S3 with DynamoDB state locking
#
# Backend configuration is intentionally minimal here.
# Actual backend values are provided during initialization via:
# - Command line: terraform init -backend-config=backend-config.tfvars
# - Or in environment-specific directories
#
# Security:
# - S3 bucket has versioning enabled for state recovery
# - S3 bucket is encrypted at rest with AES256
# - DynamoDB provides state locking to prevent concurrent modifications
# - All access is controlled via IAM

# Backend configuration is commented out for initial testing
# Uncomment and configure when ready to use remote state
#
# terraform {
#   backend "s3" {
#     # Backend configuration will be provided via:
#     # 1. Environment-specific backend-config.tfvars file
#     # 2. Or command-line flags during terraform init
#     #
#     # Required values:
#     # - bucket: S3 bucket name for state storage
#     # - key: Path to state file within bucket
#     # - region: AWS region for S3 bucket
#     # - dynamodb_table: DynamoDB table for state locking
#     # - encrypt: Enable encryption at rest (should be true)
#   }
# }
