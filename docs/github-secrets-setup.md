# GitHub Secrets Setup Guide

This guide explains how to configure GitHub environment secrets for CI/CD workflows.

## Overview

The CI/CD workflows require environment-specific secrets to authenticate with AWS and deploy to ECS. Each environment (dev, prod) has its own set of secrets.

## Required Secrets Per Environment

Each GitHub environment needs 7 secrets configured:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `ECR_BACKEND_REPOSITORY` | Full ECR backend repo URI | `108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend` |
| `ECR_FRONTEND_REPOSITORY` | Full ECR frontend repo URI | `108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend` |
| `ECS_CLUSTER` | ECS cluster name | `dev-davidshaevel-cluster` |
| `ECS_BACKEND_SERVICE` | ECS backend service name | `dev-davidshaevel-backend` |
| `ECS_FRONTEND_SERVICE` | ECS frontend service name | `dev-davidshaevel-frontend` |

---

## Step 1: Create GitHub Environment

### Via GitHub UI

1. Navigate to repository: **Settings → Environments**
2. Click **New environment**
3. Name: `dev` (or `prod`)
4. Click **Configure environment**
5. (Optional) Add protection rules:
   - Required reviewers
   - Wait timer
   - Deployment branches: Only `main`

### Verification

```bash
# List environments
gh api repos/davidshaevel-dot-com/davidshaevel-platform/environments \
  --jq '.environments[].name'
```

---

## Step 2: Gather Required Values

### AWS Credentials

**Prerequisites:**
- IAM user created with CI/CD policy attached
- For dev: `dev-davidshaevel-github-actions`
- For prod: `prod-davidshaevel-github-actions`

```bash
# Get IAM user details
aws iam get-user --user-name dev-davidshaevel-github-actions

# Create access keys (if not already created)
aws iam create-access-key --user-name dev-davidshaevel-github-actions
```

**Save the output:**
- `AccessKeyId` → `AWS_ACCESS_KEY_ID`
- `SecretAccessKey` → `AWS_SECRET_ACCESS_KEY`

⚠️ **Security Warning:** Store access keys securely. The secret access key is only shown once.

### AWS Region

For all environments:
```
us-east-1
```

### ECR Repository URIs

```bash
# Get ECR repository URIs
aws ecr describe-repositories \
  --profile davidshaevel-dev \
  --repository-names davidshaevel/backend davidshaevel/frontend \
  --query 'repositories[*].[repositoryName,repositoryUri]' \
  --output table
```

Example output:
```
davidshaevel/backend   → 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend
davidshaevel/frontend  → 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend
```

### ECS Resource Names

From Terraform outputs or AWS CLI:

```bash
# Get ECS cluster name
aws ecs list-clusters --profile davidshaevel-dev

# Get ECS service names
aws ecs list-services --profile davidshaevel-dev --cluster dev-davidshaevel-cluster
```

Example values:
```
Cluster:         dev-davidshaevel-cluster
Backend Service: dev-davidshaevel-backend
Frontend Service: dev-davidshaevel-frontend
```

---

## Step 3: Configure Secrets

### Via GitHub CLI (Recommended)

```bash
# Set AWS credentials
gh secret set AWS_ACCESS_KEY_ID --env dev
# Paste the access key ID when prompted

gh secret set AWS_SECRET_ACCESS_KEY --env dev
# Paste the secret access key when prompted

# Set AWS region
echo "us-east-1" | gh secret set AWS_REGION --env dev

# Set ECS cluster name
echo "dev-davidshaevel-cluster" | gh secret set ECS_CLUSTER --env dev

# Set ECR repositories (paste full URIs)
echo "108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend" | \
  gh secret set ECR_BACKEND_REPOSITORY --env dev

echo "108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend" | \
  gh secret set ECR_FRONTEND_REPOSITORY --env dev

# Set ECS service names
echo "dev-davidshaevel-backend" | gh secret set ECS_BACKEND_SERVICE --env dev
echo "dev-davidshaevel-frontend" | gh secret set ECS_FRONTEND_SERVICE --env dev
```

### Via GitHub UI

1. Navigate to: **Settings → Environments → [environment] → Environment secrets**
2. Click **Add secret**
3. Name: Enter secret name (e.g., `AWS_ACCESS_KEY_ID`)
4. Value: Enter secret value
5. Click **Add secret**
6. Repeat for all 7 secrets

---

## Step 4: Verify Configuration

### List All Secrets

```bash
# List secrets in dev environment
gh secret list --env dev
```

**Expected output:**
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

### Test Secrets

Trigger a manual workflow to verify secrets work:

```bash
# Test backend deployment
gh workflow run backend-deploy.yml --field environment=dev

# Monitor workflow
gh run list --workflow=backend-deploy.yml --limit 1
gh run watch <run-id>
```

**Success indicators:**
- ✅ AWS authentication succeeds
- ✅ ECR login succeeds
- ✅ ECS service update succeeds
- ✅ Workflow completes successfully

**Common errors:**
- `Error: RepositoryNotFoundException` → ECR repository URI incorrect
- `Error: ServiceNotFoundException` → ECS service name incorrect
- `Error: no basic auth credentials` → AWS credentials incorrect

---

## Step 5: Production Environment Setup

For production environment, repeat all steps above with prod-specific values:

### IAM User

```bash
# Create prod IAM user
aws iam create-user --user-name prod-davidshaevel-github-actions

# Attach policy (must be created first)
aws iam attach-user-policy \
  --user-name prod-davidshaevel-github-actions \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/prod-davidshaevel-github-actions-policy

# Create access keys
aws iam create-access-key --user-name prod-davidshaevel-github-actions
```

### Production Values

```bash
# Create prod environment
gh api --method POST repos/davidshaevel-dot-com/davidshaevel-platform/environments \
  -f name=prod

# Set prod secrets (same process as dev, different values)
gh secret set AWS_ACCESS_KEY_ID --env prod
gh secret set AWS_SECRET_ACCESS_KEY --env prod
echo "us-east-1" | gh secret set AWS_REGION --env prod
# ... continue with prod-specific values
```

---

## Secret Rotation

### When to Rotate

- Every 90 days (recommended)
- After team member departure
- If credentials potentially compromised
- During security audits

### Rotation Process

1. **Create new IAM access keys:**
   ```bash
   aws iam create-access-key --user-name dev-davidshaevel-github-actions
   ```

2. **Update GitHub secrets:**
   ```bash
   gh secret set AWS_ACCESS_KEY_ID --env dev
   gh secret set AWS_SECRET_ACCESS_KEY --env dev
   ```

3. **Test with manual deployment:**
   ```bash
   gh workflow run backend-deploy.yml --field environment=dev
   ```

4. **Delete old access keys:**
   ```bash
   aws iam delete-access-key \
     --user-name dev-davidshaevel-github-actions \
     --access-key-id <old-access-key-id>
   ```

---

## Security Best Practices

### IAM Permissions

✅ **DO:**
- Use dedicated IAM user per environment
- Apply least-privilege policy
- Enable MFA for IAM users (where applicable)
- Rotate access keys regularly
- Monitor CloudTrail for API usage

❌ **DON'T:**
- Use root account credentials
- Share credentials across environments
- Commit credentials to git
- Use overly permissive policies

### GitHub Environment Protection

For **production**, configure:
- ✅ Required reviewers (1-2 people)
- ✅ Deployment branches: Only `main`
- ✅ Wait timer (optional, e.g., 5 minutes)

For **dev**:
- Can be less restrictive
- Allows faster iteration

### Secret Management

- Never log secrets in workflow outputs
- Use GitHub's secret masking (automatic)
- Avoid echoing secrets to stdout
- Use environment-specific secrets (no shared secrets)

---

## Troubleshooting

### Secret Not Found Error

```
Error: Secret AWS_ACCESS_KEY_ID not found
```

**Solution:**
- Verify secret name matches exactly (case-sensitive)
- Check secret is set in correct environment
- List secrets: `gh secret list --env dev`

### Invalid Credentials Error

```
Error: The security token included in the request is invalid
```

**Solution:**
- Verify access key is active: `aws iam list-access-keys --user-name dev-davidshaevel-github-actions`
- Check IAM user has required policy attached
- Recreate access keys if needed

### Permission Denied Error

```
Error: User is not authorized to perform: ecr:GetAuthorizationToken
```

**Solution:**
- Verify IAM policy is attached to user
- Check policy includes required permissions
- Review CloudTrail logs for detailed error

---

## Quick Reference

### List All Secrets

```bash
gh secret list --env dev
gh secret list --env prod
```

### Update Single Secret

```bash
gh secret set AWS_ACCESS_KEY_ID --env dev
```

### Delete Secret

```bash
gh secret remove AWS_ACCESS_KEY_ID --env dev
```

### View Environment Details

```bash
gh api repos/davidshaevel-dot-com/davidshaevel-platform/environments/dev
```

---

**Document Version:** 1.0  
**Last Updated:** November 6, 2025  
**See Also:** [docs/prod-environment-setup.md](prod-environment-setup.md)
