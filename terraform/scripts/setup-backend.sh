#!/bin/bash
# Terraform Backend Setup Script
# Creates S3 bucket and DynamoDB table for Terraform remote state management
#
# Project: DavidShaevel.com Platform
# Date: October 24, 2025
#
# This script should only be run ONCE to initialize the backend resources.
# After creation, these resources will be used by all Terraform operations.

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - obtained from environment variables
# Source .envrc before running this script: source .envrc
AWS_ACCOUNT_ID="${TF_VAR_aws_account_id}"
PROJECT_NAME="${TF_VAR_project_name}"
AWS_REGION="${TF_VAR_aws_region:-us-east-1}"
BUCKET_NAME="${AWS_ACCOUNT_ID}-terraform-state-${PROJECT_NAME}"
DYNAMODB_TABLE="terraform-state-lock-${PROJECT_NAME}"

# Validate required environment variables
if [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Error: Required environment variables not set${NC}"
    echo "Please source .envrc first:"
    echo "  source .envrc"
    echo ""
    echo "Required variables:"
    echo "  TF_VAR_aws_account_id"
    echo "  TF_VAR_project_name"
    echo "  TF_VAR_aws_region (optional, defaults to us-east-1)"
    exit 1
fi

echo "======================================"
echo "Terraform Backend Setup"
echo "======================================"
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "Project: ${PROJECT_NAME}"
echo "Region: ${AWS_REGION}"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "======================================"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid${NC}"
    echo "Please run 'aws configure sso' or 'aws configure' first"
    exit 1
fi

# Verify correct AWS account
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
if [ "$CURRENT_ACCOUNT" != "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Wrong AWS account${NC}"
    echo "Expected: ${AWS_ACCOUNT_ID}"
    echo "Current: ${CURRENT_ACCOUNT}"
    echo ""
    echo "Make sure TF_VAR_aws_account_id matches your AWS account"
    exit 1
fi

echo -e "${GREEN}✓ AWS credentials verified${NC}"
echo ""

# Check if S3 bucket already exists using head-bucket (more reliable)
if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "Creating S3 bucket: ${BUCKET_NAME}"

    # Create S3 bucket
    aws s3 mb "s3://${BUCKET_NAME}" --region "${AWS_REGION}"
    echo -e "${GREEN}✓ S3 bucket created${NC}"

    # Enable versioning
    echo "Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    echo -e "${GREEN}✓ Versioning enabled${NC}"

    # Enable encryption
    echo "Enabling encryption..."
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }'
    echo -e "${GREEN}✓ Encryption enabled${NC}"

    # Block public access
    echo "Blocking public access..."
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo -e "${GREEN}✓ Public access blocked${NC}"

    # Add tags
    echo "Adding tags..."
    aws s3api put-bucket-tagging \
        --bucket "${BUCKET_NAME}" \
        --tagging "TagSet=[{Key=Project,Value=${PROJECT_NAME}},{Key=Purpose,Value=TerraformState}]"
    echo -e "${GREEN}✓ Tags added${NC}"

else
    echo -e "${YELLOW}⚠ S3 bucket already exists: ${BUCKET_NAME}${NC}"
    echo "Skipping S3 bucket creation..."
fi

echo ""

# Check if DynamoDB table already exists
if ! aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" &> /dev/null; then
    echo "Creating DynamoDB table: ${DYNAMODB_TABLE}"

    # Create DynamoDB table
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}" \
        --tags Key=Project,Value=${PROJECT_NAME} Key=Purpose,Value=TerraformStateLocking

    echo -e "${GREEN}✓ DynamoDB table created${NC}"

    # Wait for table to be active
    echo "Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}"
    echo -e "${GREEN}✓ DynamoDB table is active${NC}"

else
    echo -e "${YELLOW}⚠ DynamoDB table already exists: ${DYNAMODB_TABLE}${NC}"
    echo "Skipping DynamoDB table creation..."
fi

echo ""
echo "======================================"
echo -e "${GREEN}Backend Setup Complete!${NC}"
echo "======================================"
echo ""
echo "Resources created:"
echo "  S3 Bucket: s3://${BUCKET_NAME}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo ""
echo "You can now initialize Terraform with these backend settings:"
echo ""
echo "  bucket         = \"${BUCKET_NAME}\""
echo "  dynamodb_table = \"${DYNAMODB_TABLE}\""
echo "  region         = \"${AWS_REGION}\""
echo "  encrypt        = true"
echo ""
echo "Next steps:"
echo "  1. Configure backend in your Terraform files"
echo "  2. Run 'terraform init' to initialize the backend"
echo "  3. Run 'terraform plan' to verify configuration"
echo ""
