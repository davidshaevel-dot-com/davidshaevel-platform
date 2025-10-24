# Terraform Backend Setup Log

**Date:** October 24, 2025
**Environment:** Development
**AWS Account:** [Your AWS Account ID]
**Executed By:** [Your Name]

**Note:** This document contains example commands with placeholder values.
Replace `123456789012` with your actual AWS account ID and `myproject` with your project name.

---

## Summary

Set up AWS resources required for Terraform remote state management:
- S3 bucket for storing Terraform state files
- DynamoDB table for state locking

---

## Prerequisites Completed

✅ Terraform v1.13.4+ installed
✅ AWS CLI v2.x installed
✅ AWS SSO configured with profile (e.g., `myproject-dev`)
✅ IAM Role: `AdministratorAccess` or equivalent
✅ Account verified

---

## Commands Executed

### 1. AWS SSO Configuration

```bash
# Configured AWS SSO
aws configure sso

# Configuration details:
# - SSO session name: [your-session-name]
# - SSO start URL: [your SSO URL]
# - SSO Region: us-east-1
# - Account: [your 12-digit AWS account ID]
# - Role: AdministratorAccess
# - Default region: us-east-1
# - Profile name: [your-profile-name] (e.g., myproject-dev)
```

### 2. Verified AWS Credentials

```bash
aws sts get-caller-identity --profile myproject-dev

# Output example:
# {
#     "UserId": "AROAXXXXXXXXXXXXXXXXX:username",
#     "Account": "123456789012",
#     "Arn": "arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_AdministratorAccess_xxxxx/username"
# }
```

### 3. Created Environment Configuration

Created `.envrc` file (example values shown):
```bash
export AWS_PROFILE=myproject-dev
export AWS_DEFAULT_REGION=us-east-1
export AWS_REGION=us-east-1
export TF_VAR_aws_account_id="123456789012"
export TF_VAR_project_name="myproject"
export TF_VAR_aws_region="us-east-1"
export TF_VAR_environment="dev"
export TF_VAR_domain_name="example.com"
```

**Security:** `.envrc` contains sensitive data and is excluded from Git via `.gitignore`

### 4. Created S3 Bucket for Terraform State

```bash
# Source environment variables first
source .envrc

# Create bucket (uses environment variables)
aws s3 mb s3://123456789012-terraform-state-myproject --region us-east-1

# Or use the automated script:
./terraform/scripts/setup-backend.sh
```

**Bucket Name:** `<account-id>-terraform-state-<project-name>`
**Region:** us-east-1
**Purpose:** Store Terraform state files

### 5. Enabled Bucket Versioning

```bash
aws s3api put-bucket-versioning \
  --bucket 123456789012-terraform-state-myproject \
  --versioning-configuration Status=Enabled
```

**Why:** Allows recovery of previous state versions if needed

### 6. Enabled Bucket Encryption

```bash
aws s3api put-bucket-encryption \
  --bucket 123456789012-terraform-state-myproject \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

**Encryption:** AES256
**Bucket Key:** Enabled (reduces S3 encryption costs)

### 7. Blocked Public Access

```bash
aws s3api put-public-access-block \
  --bucket 123456789012-terraform-state-myproject \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**Security:** All public access blocked (best practice for state files)

### 8. Verified Bucket Configuration

```bash
aws s3api get-bucket-versioning \
  --bucket 123456789012-terraform-state-myproject

# Output:
# {
#     "Status": "Enabled"
# }
```

### 9. Created DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock-myproject \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 \
  --tags Key=Project,Value=myproject Key=Purpose,Value=TerraformStateLocking
```

**Table Name:** `terraform-state-lock-<project-name>`
**Key:** LockID (String)
**Billing Mode:** PAY_PER_REQUEST (no provisioned capacity needed)
**Purpose:** Prevent concurrent Terraform operations

### 10. Verified DynamoDB Table

```bash
aws dynamodb describe-table \
  --table-name terraform-state-lock-myproject \
  --query 'Table.TableStatus' \
  --output text

# Output: ACTIVE
```

---

## Resources Created

| Resource Type | Name | ARN/URL |
|--------------|------|---------|
| S3 Bucket | `<account-id>-terraform-state-<project>` | s3://123456789012-terraform-state-myproject |
| DynamoDB Table | `terraform-state-lock-<project>` | arn:aws:dynamodb:us-east-1:123456789012:table/terraform-state-lock-myproject |

---

## Backend Configuration for Terraform

Use these values in your Terraform backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "123456789012-terraform-state-myproject"
    key            = "env/terraform.tfstate"  # Change per environment
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-myproject"
    encrypt        = true
    profile        = "myproject-dev"
  }
}
```

**Note:** Replace values with your actual account ID, project name, and AWS profile.

---

## Cost Estimates

| Resource | Cost |
|----------|------|
| S3 Bucket (state storage) | ~$0.01/month (for small state files) |
| S3 Requests | ~$0.01/month (minimal requests) |
| DynamoDB Table (PAY_PER_REQUEST) | ~$0.00/month (minimal lock operations) |
| **Total** | **~$0.02/month** |

---

## Security Features

✅ **Versioning enabled** - Can recover from accidental state corruption
✅ **Encryption at rest** - AES256 encryption for all state files
✅ **Public access blocked** - No public read/write access
✅ **State locking** - Prevents concurrent modifications
✅ **IAM-based access** - Only authorized users can access state
✅ **Bucket keys enabled** - Reduced encryption costs

---

## Validation Commands

Test that everything is working:

```bash
# Source environment variables
source .envrc

# Verify S3 bucket exists
aws s3 ls s3://123456789012-terraform-state-myproject

# Verify bucket versioning
aws s3api get-bucket-versioning \
  --bucket 123456789012-terraform-state-myproject

# Verify DynamoDB table
aws dynamodb describe-table \
  --table-name terraform-state-lock-myproject
```

---

## Automation Script

A reusable script has been created for future reference or other projects:

**Location:** `terraform/scripts/setup-backend.sh`

**Usage:**
```bash
# Source environment variables first
source .envrc

# Make executable (first time only)
chmod +x terraform/scripts/setup-backend.sh

# Run the script
./terraform/scripts/setup-backend.sh
```

The script is idempotent - it will skip resources that already exist.

---

## Next Steps

1. ✅ Backend resources created
2. ⏭️ Create Terraform configuration files
3. ⏭️ Initialize Terraform with `terraform init`
4. ⏭️ Test backend with `terraform plan`

---

## Troubleshooting

### If you need to recreate the backend:

```bash
# Source environment first
source .envrc

# Delete DynamoDB table (replace with your table name)
aws dynamodb delete-table --table-name terraform-state-lock-myproject

# Empty and delete S3 bucket (replace with your bucket name)
aws s3 rm s3://123456789012-terraform-state-myproject --recursive
aws s3 rb s3://123456789012-terraform-state-myproject

# Re-run setup script
./terraform/scripts/setup-backend.sh
```

### If state locking fails:

```bash
# Check for stuck locks (replace with your table name)
aws dynamodb scan --table-name terraform-state-lock-myproject

# Force unlock (use with caution!)
terraform force-unlock <lock-id>
```

---

## Notes

- Backend is configured for the entire project (all environments)
- Each environment will use a different state file key
- SSO credentials will need to be refreshed periodically (`aws sso login`)
- Never commit state files or `.envrc` to Git

---

**Setup Status:** ✅ Complete
**Verified:** October 24, 2025
**Related Issues:** TT-16
