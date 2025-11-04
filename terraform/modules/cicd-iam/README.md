# CI/CD IAM Module

Creates an IAM user and policy for GitHub Actions to deploy applications to ECS Fargate.

## Purpose

This module implements the **Terraform hybrid approach** for CI/CD credentials:
- **Terraform manages:** IAM user, policy, and policy attachment
- **Manual process:** Access key generation (keeps secrets out of Terraform state)

## Resources Created

- `aws_iam_user.github_actions` - IAM user for GitHub Actions
- `aws_iam_policy.github_actions_deployment` - Minimal permissions policy
- `aws_iam_user_policy_attachment.github_actions_deployment` - Attaches policy to user

## Permissions Granted

### ECR (Elastic Container Registry)
- Get authorization token
- Push Docker images
- Manage image layers

### ECS (Elastic Container Service)
- Describe services and task definitions
- Register new task definitions
- Update services for deployments
- List and describe tasks

### IAM
- PassRole for ECS task execution and task roles (scoped to specific roles)

### CloudWatch Logs
- Create and write to log groups under `/ecs/davidshaevel/*`

## Usage

### Step 1: Add Module to Environment

In `terraform/environments/dev/main.tf`:

```hcl
module "cicd_iam" {
  source = "../../modules/cicd-iam"

  environment    = "dev"
  project_name   = "davidshaevel"
  aws_account_id = "108581769167"
  aws_region     = "us-east-1"
}
```

### Step 2: Apply Terraform

```bash
cd terraform/environments/dev
export AWS_PROFILE=davidshaevel-dev
terraform init
terraform plan
terraform apply
```

**Terraform will create:**
- IAM user: `dev-davidshaevel-github-actions`
- IAM policy: `dev-davidshaevel-github-actions-deployment`

### Step 3: Generate Access Keys (Manual)

**Why manual?** Keeps AWS secret access keys OUT of Terraform state file.

1. **Open AWS Console** → IAM → Users
2. **Click on user:** `dev-davidshaevel-github-actions`
3. **Security credentials tab** → **Create access key**
4. **Use case:** Select "Application running outside AWS"
5. **Description:** "GitHub Actions CI/CD for DavidShaevel.com Platform"
6. **Copy credentials:**
   ```
   AWS_ACCESS_KEY_ID:     AKIA...
   AWS_SECRET_ACCESS_KEY: wJa...
   ```

⚠️ **Save these temporarily** - you won't see the secret key again!

### Step 4: Configure GitHub Secrets

1. Navigate to GitHub repository: **Settings → Secrets and variables → Actions**
2. Add these secrets:
   - `AWS_ACCESS_KEY_ID` = (from Step 3)
   - `AWS_SECRET_ACCESS_KEY` = (from Step 3)
   - `AWS_REGION` = `us-east-1`
   - `ECR_BACKEND_REPOSITORY` = `108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend`
   - `ECR_FRONTEND_REPOSITORY` = `108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend`
   - `ECS_CLUSTER` = `dev-davidshaevel-cluster`
   - `ECS_BACKEND_SERVICE` = `backend`
   - `ECS_FRONTEND_SERVICE` = `frontend`

### Step 5: Delete Temporary Credentials

**Securely delete** any temporary files containing the access keys.

## Outputs

After `terraform apply`, you'll see:

```
Outputs:

user_name = "dev-davidshaevel-github-actions"
user_arn = "arn:aws:iam::108581769167:user/cicd/dev-davidshaevel-github-actions"
policy_name = "dev-davidshaevel-github-actions-deployment"
```

## Security Notes

**Least Privilege:** Policy grants only minimum permissions needed for ECS deployments.

**No Console Access:** User has programmatic access only (no AWS Console login).

**Path-based Organization:** User and policy use `/cicd/` path for organizational clarity.

**Scoped Resources:**
- IAM PassRole: Only specific task execution and task roles
- CloudWatch Logs: Only `/ecs/davidshaevel/*` log groups
- ECR/ECS: Currently all resources (can be scoped tighter if needed)

**Best Practices:**
- Rotate access keys every 90 days
- Monitor CloudTrail for unexpected API calls
- Review policy permissions periodically
- Use separate IAM user for local development (existing `davidshaevel-dev` profile)

## Maintenance

### Rotating Access Keys

1. Generate new keys in AWS Console (Step 3 above)
2. Update GitHub Secrets with new keys
3. Test deployments with new keys
4. Delete old access keys in AWS Console

### Updating Permissions

Edit `terraform/modules/cicd-iam/main.tf` policy:
1. Modify the `aws_iam_policy.github_actions_deployment` resource
2. Run `terraform plan` to review changes
3. Run `terraform apply` to update policy

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name (dev, prod) | string | - | yes |
| project_name | Project name for resource naming | string | "davidshaevel" | no |
| aws_account_id | AWS Account ID for IAM ARNs | string | - | yes |
| aws_region | AWS Region for CloudWatch ARNs | string | "us-east-1" | no |

## Outputs

| Name | Description |
|------|-------------|
| user_name | Name of the GitHub Actions IAM user |
| user_arn | ARN of the GitHub Actions IAM user |
| user_unique_id | Unique ID of the GitHub Actions IAM user |
| policy_arn | ARN of the deployment policy |
| policy_name | Name of the deployment policy |

---

**Next Steps:** Configure GitHub Secrets (Step 4) and implement GitHub Actions workflows.
