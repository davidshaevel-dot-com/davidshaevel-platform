# Terraform Local Development Setup Guide

**Project:** DavidShaevel.com Platform
**Purpose:** Bootstrap your local environment for Terraform development and testing
**Date:** October 24, 2025

---

## Prerequisites Checklist

Before starting, ensure you have the following installed:

- [ ] **Terraform** (version 1.5.0 or later)
- [ ] **AWS CLI** (version 2.x)
- [ ] **Git** (for version control)
- [ ] **Code Editor** (VS Code recommended with Terraform extension)
- [ ] **jq** (for JSON processing - optional but helpful)

---

## Step 1: Install Required Tools

### Install Terraform

**macOS (using Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Verify installation:**
```bash
terraform version
# Expected: Terraform v1.5.0 or later
```

### Install AWS CLI

**macOS (using Homebrew):**
```bash
brew install awscli
```

**Verify installation:**
```bash
aws --version
# Expected: aws-cli/2.x.x
```

### Install jq (Optional)

**macOS (using Homebrew):**
```bash
brew install jq
```

### Install VS Code Extensions (Recommended)

If using VS Code:
1. Open VS Code
2. Install "HashiCorp Terraform" extension
3. Install "AWS Toolkit" extension

---

## Step 2: Configure AWS Credentials

### Option A: Using AWS CLI Configuration (Recommended)

```bash
# Configure AWS credentials interactively
aws configure

# You'll be prompted for:
# AWS Access Key ID: [your access key]
# AWS Secret Access Key: [your secret key]
# Default region name: us-east-1
# Default output format: json
```

### Option B: Using Environment Variables

```bash
# Add to your ~/.zshrc or ~/.bashrc
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Reload shell configuration
source ~/.zshrc  # or source ~/.bashrc
```

### Verify AWS Configuration

```bash
# Check your AWS identity
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "...",
#     "Account": "108581769167",
#     "Arn": "arn:aws:iam::108581769167:user/your-username"
# }
```

**Important:** Ensure the Account ID matches: `108581769167`

---

## Step 3: Set Up Terraform Backend (One-Time Setup)

The Terraform state will be stored remotely in AWS S3 with DynamoDB locking.

### Create S3 Bucket for State

```bash
# Set variables
export AWS_ACCOUNT_ID="108581769167"
export PROJECT_NAME="davidshaevel"
export AWS_REGION="us-east-1"

# Create S3 bucket
aws s3 mb s3://${AWS_ACCOUNT_ID}-terraform-state-${PROJECT_NAME} \
  --region ${AWS_REGION}

# Enable versioning (important for state recovery)
aws s3api put-bucket-versioning \
  --bucket ${AWS_ACCOUNT_ID}-terraform-state-${PROJECT_NAME} \
  --versioning-configuration Status=Enabled

# Enable encryption at rest
aws s3api put-bucket-encryption \
  --bucket ${AWS_ACCOUNT_ID}-terraform-state-${PROJECT_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Block public access (security best practice)
aws s3api put-public-access-block \
  --bucket ${AWS_ACCOUNT_ID}-terraform-state-${PROJECT_NAME} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Create DynamoDB Table for State Locking

```bash
# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock-${PROJECT_NAME} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION} \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Purpose,Value=TerraformStateLocking
```

### Verify Backend Resources

```bash
# Verify S3 bucket
aws s3 ls | grep terraform-state

# Verify DynamoDB table
aws dynamodb describe-table \
  --table-name terraform-state-lock-${PROJECT_NAME} \
  --query 'Table.TableStatus' \
  --output text
# Expected: ACTIVE
```

---

## Step 4: Configure Your Local Terraform Environment

### Set Up Environment Variables

Create a `.envrc` file in the project root (if using direnv) or add to your shell config:

```bash
# Add to ~/.zshrc or create .envrc
export TF_VAR_aws_account_id="108581769167"
export TF_VAR_project_name="davidshaevel"
export TF_VAR_aws_region="us-east-1"
export TF_VAR_environment="dev"
```

### Install direnv (Optional but Recommended)

```bash
# Install direnv
brew install direnv

# Add to ~/.zshrc
eval "$(direnv hook zsh)"

# Create .envrc in project root
cat > .envrc << 'EOF'
export TF_VAR_aws_account_id="108581769167"
export TF_VAR_project_name="davidshaevel"
export TF_VAR_aws_region="us-east-1"
export TF_VAR_environment="dev"
EOF

# Allow direnv to load
direnv allow
```

---

## Step 5: Verify Your Setup

Run these commands to ensure everything is configured correctly:

```bash
# 1. Check Terraform version
terraform version

# 2. Check AWS credentials
aws sts get-caller-identity

# 3. Check S3 backend bucket exists
aws s3 ls s3://108581769167-terraform-state-davidshaevel

# 4. Check DynamoDB table exists
aws dynamodb describe-table --table-name terraform-state-lock-davidshaevel

# 5. Test Terraform formatting (should work even without files)
terraform fmt -check
```

---

## Step 6: Understanding the Development Workflow

### Terraform Development Cycle

```
1. Write/Edit Terraform files
   ↓
2. Format code: terraform fmt
   ↓
3. Validate syntax: terraform validate
   ↓
4. Review changes: terraform plan
   ↓
5. Apply changes: terraform apply
   ↓
6. Test resources in AWS
   ↓
7. Commit to Git
   ↓
8. Push and create PR
```

### Key Commands You'll Use Daily

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Initialize Terraform (run after adding new modules)
terraform init

# Plan changes (dry run)
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources in state
terraform state list

# Destroy specific resource (for testing)
terraform destroy -target=module.vpc.aws_vpc.main
```

---

## Step 7: Set Up Git Workflow

### Configure Git for This Project

```bash
# Ensure you're in the project root
cd /Users/dshaevel/workspace-ds/davidshaevel-platform

# Check current branch
git branch --show-current
# Should be: claude/tt-16-terraform-project-structure

# Configure git to ignore Terraform files we don't want to commit
cat >> .gitignore << 'EOF'

# Terraform
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
.terraform.lock.hcl
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
EOF
```

---

## Step 8: Cost Monitoring Setup (Important!)

Set up billing alerts to avoid surprise charges:

```bash
# Create SNS topic for billing alerts
aws sns create-topic --name billing-alerts-davidshaevel

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:108581769167:billing-alerts-davidshaevel \
  --protocol email \
  --notification-endpoint your-email@example.com

# Note: You'll need to confirm the subscription via email
```

**Set up CloudWatch billing alarm:**
1. Go to AWS Console → CloudWatch → Billing → Create Alarm
2. Set threshold: $10 USD
3. Configure SNS notification
4. This will alert you if costs exceed $10/month

---

## Troubleshooting

### Issue: "Access Denied" when creating S3 bucket

**Solution:** Ensure your AWS IAM user has permissions:
- `s3:CreateBucket`
- `s3:PutBucketVersioning`
- `s3:PutBucketEncryption`
- `dynamodb:CreateTable`

### Issue: "Backend initialization failed"

**Solution:**
```bash
# Remove cached backend config
rm -rf .terraform

# Re-initialize
terraform init -reconfigure
```

### Issue: "State lock timeout"

**Solution:**
```bash
# Check for stuck locks
aws dynamodb scan --table-name terraform-state-lock-davidshaevel

# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

### Issue: "AWS credentials not found"

**Solution:**
```bash
# Re-configure AWS CLI
aws configure

# Or set environment variables explicitly
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

---

## Next Steps

Once your environment is set up:

1. ✅ Review this guide and complete all steps
2. ✅ Verify all checklist items
3. ✅ Run the verification commands in Step 5
4. ✅ Ready to start creating Terraform files!

---

## Quick Reference Card

Save this for daily use:

```bash
# Daily workflow commands
terraform fmt -recursive        # Format code
terraform validate              # Check syntax
terraform plan                  # Preview changes
terraform apply                 # Apply changes
git add . && git commit -m ""  # Commit changes
git push                        # Push to remote

# Debugging commands
terraform show                  # Show current state
terraform state list            # List all resources
terraform console               # Interactive console
terraform graph | dot -Tpng > graph.png  # Visualize

# Cleanup commands
terraform destroy               # Destroy all resources
rm -rf .terraform              # Clean local cache
```

---

**Setup Complete! 🎉**

You're now ready to start developing Terraform infrastructure incrementally.

Next: Review the incremental implementation plan in `docs/terraform-implementation-plan.md`
