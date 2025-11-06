# Production Environment Setup Guide

This guide documents the steps required to set up the production (prod) environment for CI/CD deployments.

## Prerequisites

1. Production AWS infrastructure must be deployed via Terraform
2. GitHub repository admin access to create environments and secrets

## Production Infrastructure Deployment

The production infrastructure is defined in `terraform/environments/prod/` but has not been applied yet.

### Steps to Deploy Prod Infrastructure

1. **Configure Terraform backend:**
   ```bash
   cd terraform/environments/prod
   cp backend-config.tfvars.example backend-config.tfvars
   # Edit backend-config.tfvars with prod S3 bucket details
   ```

2. **Configure Terraform variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with prod environment values
   ```

3. **Initialize and apply Terraform:**
   ```bash
   terraform init -backend-config=backend-config.tfvars
   terraform plan
   terraform apply
   ```

4. **Capture output values:**
   ```bash
   terraform output
   ```
   Save the following outputs for GitHub secrets configuration:
   - `ecr_backend_repository_url`
   - `ecr_frontend_repository_url`
   - `ecs_cluster_name`
   - `ecs_backend_service_name`
   - `ecs_frontend_service_name`

## GitHub Environment Configuration

### Step 1: Create Production Environment

The prod environment must be created in GitHub repository settings:

1. Navigate to: Settings → Environments → New environment
2. Name: `prod`
3. Configure protection rules (recommended):
   - ✅ Required reviewers (1-2 people)
   - ✅ Wait timer (optional - e.g., 5 minutes)
   - ⚠️ Deployment branches: Only `main` branch

### Step 2: Configure GitHub Secrets for Prod

Once the prod environment is created, configure these secrets:

```bash
# Set AWS_REGION (same for all environments)
echo "us-east-1" | gh secret set AWS_REGION --env prod

# Set AWS credentials (prod-specific IAM user)
gh secret set AWS_ACCESS_KEY_ID --env prod
# Paste the prod IAM access key when prompted

gh secret set AWS_SECRET_ACCESS_KEY --env prod
# Paste the prod IAM secret key when prompted

# Set ECS cluster name (from terraform output)
terraform output -raw ecs_cluster_name | gh secret set ECS_CLUSTER --env prod

# Set backend ECR repository (from terraform output)
terraform output -raw ecr_backend_repository_url | gh secret set ECR_BACKEND_REPOSITORY --env prod

# Set frontend ECR repository (from terraform output)
terraform output -raw ecr_frontend_repository_url | gh secret set ECR_FRONTEND_REPOSITORY --env prod

# Set backend ECS service name (from terraform output)
terraform output -raw ecs_backend_service_name | gh secret set ECS_BACKEND_SERVICE --env prod

# Set frontend ECS service name (from terraform output)
terraform output -raw ecs_frontend_service_name | gh secret set ECS_FRONTEND_SERVICE --env prod
```

### Step 3: Verify Secrets Configuration

```bash
# List all secrets in prod environment
gh secret list --env prod
```

Expected output:
```
AWS_ACCESS_KEY_ID          Updated YYYY-MM-DD
AWS_REGION                 Updated YYYY-MM-DD
AWS_SECRET_ACCESS_KEY      Updated YYYY-MM-DD
ECR_BACKEND_REPOSITORY     Updated YYYY-MM-DD
ECR_FRONTEND_REPOSITORY    Updated YYYY-MM-DD
ECS_BACKEND_SERVICE        Updated YYYY-MM-DD
ECS_CLUSTER                Updated YYYY-MM-DD
ECS_FRONTEND_SERVICE       Updated YYYY-MM-DD
```

## IAM User for Production CI/CD

A dedicated IAM user should be created for production deployments with least-privilege permissions.

### Required IAM Permissions

The production IAM user requires the same permissions as dev:

1. **ECR Permissions:**
   - `ecr:GetAuthorizationToken`
   - `ecr:BatchCheckLayerAvailability`
   - `ecr:GetDownloadUrlForLayer`
   - `ecr:BatchGetImage`
   - `ecr:InitiateLayerUpload`
   - `ecr:UploadLayerPart`
   - `ecr:CompleteLayerUpload`
   - `ecr:PutImage`

2. **ECS Permissions:**
   - `ecs:DescribeTaskDefinition`
   - `ecs:RegisterTaskDefinition`
   - `ecs:UpdateService`
   - `ecs:DescribeServices`

3. **ELB Permissions (for service URL retrieval):**
   - `elasticloadbalancing:DescribeTargetGroups`
   - `elasticloadbalancing:DescribeLoadBalancers`

4. **IAM Permissions (for task execution role):**
   - `iam:PassRole` (limited to task execution role ARNs)

### Creating Production IAM User

```bash
# Create IAM user for prod CI/CD
aws iam create-user --user-name prod-davidshaevel-github-actions

# Attach policy (must be created first - see terraform/modules/iam_cicd/)
aws iam attach-user-policy \
  --user-name prod-davidshaevel-github-actions \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/prod-davidshaevel-github-actions-policy

# Create access keys
aws iam create-access-key --user-name prod-davidshaevel-github-actions
```

Save the access key ID and secret access key for GitHub secrets configuration.

## Testing Production Deployment

### Manual Workflow Trigger

Test the production deployment using manual workflow dispatch:

```bash
# Trigger backend deployment to prod
cd /path/to/davidshaevel-platform
gh workflow run backend-deploy.yml --field environment=prod

# Trigger frontend deployment to prod
gh workflow run frontend-deploy.yml --field environment=prod
```

### Verify Deployment

1. Check workflow run status:
   ```bash
   gh run list --workflow=backend-deploy.yml --limit 5
   gh run list --workflow=frontend-deploy.yml --limit 5
   ```

2. Verify ECS services are running:
   ```bash
   aws ecs describe-services \
     --cluster prod-davidshaevel-cluster \
     --services prod-davidshaevel-backend prod-davidshaevel-frontend
   ```

3. Test service URLs (from workflow output or manual retrieval):
   ```bash
   # Get backend URL
   aws ecs describe-services \
     --cluster prod-davidshaevel-cluster \
     --services prod-davidshaevel-backend \
     --query 'services[0].loadBalancers[0].targetGroupArn' \
     --output text | xargs -I {} \
     aws elbv2 describe-target-groups \
     --target-group-arns {} \
     --query 'TargetGroups[0].LoadBalancerArns[0]' \
     --output text | xargs -I {} \
     aws elbv2 describe-load-balancers \
     --load-balancer-arns {} \
     --query 'LoadBalancers[0].DNSName' \
     --output text
   ```

## Rollback Procedures

If a production deployment fails or causes issues:

### Option 1: Redeploy Previous Version

1. Find the previous successful deployment commit SHA
2. Manually trigger workflow using the `--ref` flag with that commit SHA:
   ```bash
   # For backend
   gh workflow run backend-deploy.yml --field environment=prod --ref <previous-commit-sha>

   # For frontend
   gh workflow run frontend-deploy.yml --field environment=prod --ref <previous-commit-sha>
   ```

### Option 2: Manual ECS Service Update

1. Find the previous task definition revision (example for backend):
   ```bash
   aws ecs list-task-definitions --family-prefix prod-davidshaevel-backend --sort DESC
   ```

2. Update service to previous task definition (example for backend):
   ```bash
   aws ecs update-service \
     --cluster prod-davidshaevel-cluster \
     --service prod-davidshaevel-backend \
     --task-definition prod-davidshaevel-backend:<revision-number>
   ```

   *Note: To rollback the frontend, replace `backend` with `frontend` in the service and family-prefix names.*

## Current Status

- ✅ Dev environment: Fully configured and operational
- ⏳ Prod environment: Ready for setup (infrastructure not deployed yet)

## Next Steps

1. Deploy production infrastructure via Terraform
2. Create prod GitHub environment with protection rules
3. Configure all required GitHub secrets
4. Test manual workflow dispatch to prod
5. Document any prod-specific configurations or issues
