# Deployment Runbook - DavidShaevel.com Platform

**Last Updated:** November 2, 2025
**Platform:** https://davidshaevel.com
**Environment:** AWS ECS Fargate (dev environment serving as production)

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Backend Deployment](#backend-deployment)
3. [Frontend Deployment](#frontend-deployment)
4. [Database Migrations](#database-migrations)
5. [Health Check Verification](#health-check-verification)
6. [Rollback Procedures](#rollback-procedures)
7. [Troubleshooting](#troubleshooting)
8. [Emergency Contacts](#emergency-contacts)

---

## Pre-Deployment Checklist

**Before deploying any changes, verify:**

- [ ] All tests passing locally (`backend/scripts/test-local.sh`)
- [ ] Code reviewed and merged to `main` branch
- [ ] Database migrations tested locally (if applicable)
- [ ] AWS credentials configured (`AWS_PROFILE=davidshaevel-dev`)
- [ ] Git working directory clean (`git status`)
- [ ] Current production endpoints healthy (see Health Check section)

**Required Tools:**
- AWS CLI v2 (`aws --version`)
- Docker (`docker --version`)
- Terraform v1.5+ (`terraform version`)
- Git (`git --version`)

**Required Access:**
- AWS Account: 108581769167
- AWS Profile: `davidshaevel-dev`
- Region: `us-east-1`
- ECR Repositories: `davidshaevel/backend`, `davidshaevel/frontend`

---

## Backend Deployment

### Step 1: Build Docker Image

```bash
# Navigate to backend directory
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/backend

# Get current git SHA for tagging
export IMAGE_TAG=$(git rev-parse --short HEAD)

# Build Docker image
docker build -t backend:${IMAGE_TAG} .

# Verify build succeeded
docker images | grep backend
```

**Expected Output:**
```
backend       abc1234   <timestamp>   XXX MB
```

### Step 2: Tag for ECR

```bash
# Tag image for ECR repository
docker tag backend:${IMAGE_TAG} \
  108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:${IMAGE_TAG}

# Also tag as 'latest'
docker tag backend:${IMAGE_TAG} \
  108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:latest
```

### Step 3: Login to ECR

```bash
# Authenticate Docker to ECR
AWS_PROFILE=davidshaevel-dev aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  108581769167.dkr.ecr.us-east-1.amazonaws.com
```

**Expected Output:**
```
Login Succeeded
```

### Step 4: Push to ECR

```bash
# Push tagged image
docker push 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:${IMAGE_TAG}

# Push latest tag
docker push 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:latest
```

**Monitor Progress:**
- Watch for layer uploads completing
- Final push should show digest (sha256:...)

### Step 5: Update Terraform Configuration

```bash
# Navigate to Terraform environment
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/terraform/environments/dev

# Update backend_image_tag variable in terraform.tfvars or main.tf
# Edit the file to set new image tag:
# backend_image_tag = "abc1234"  # Use your $IMAGE_TAG value

# Alternatively, pass as command-line variable:
export TF_VAR_backend_image_tag=${IMAGE_TAG}
```

### Step 6: Deploy via Terraform

```bash
# Set AWS profile
export AWS_PROFILE=davidshaevel-dev

# Review changes
terraform plan

# Apply changes
terraform apply

# When prompted, review the plan and type 'yes' to confirm
```

**Expected Changes:**
- ECS task definition updated with new image
- ECS service deployment triggered
- Old tasks drained, new tasks started

### Step 7: Monitor Deployment

```bash
# List tasks in cluster
AWS_PROFILE=davidshaevel-dev aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name backend

# Describe tasks to see status
AWS_PROFILE=davidshaevel-dev aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks <task-arn-from-previous-command>

# Watch CloudWatch logs
AWS_PROFILE=davidshaevel-dev aws logs tail \
  /ecs/davidshaevel/backend \
  --follow
```

**Wait for:**
- New tasks to reach `RUNNING` state
- Health checks to pass (`HEALTHY` in target group)
- Old tasks to stop (`STOPPED` state)

### Step 8: Verify Backend Health

```bash
# Check API health endpoint
curl https://davidshaevel.com/api/health

# Expected response:
# {"status":"ok","timestamp":"2025-11-02T...","database":"connected"}

# Check projects endpoint
curl https://davidshaevel.com/api/projects

# Should return JSON array of projects
```

**Success Criteria:**
- HTTP 200 status code
- `"status":"ok"` in response
- `"database":"connected"` confirms DB connectivity

---

## Frontend Deployment

### Step 1: Build Docker Image

```bash
# Navigate to frontend directory
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/frontend

# Get current git SHA for tagging
export IMAGE_TAG=$(git rev-parse --short HEAD)

# Build Docker image
docker build -t frontend:${IMAGE_TAG} .

# Verify build succeeded
docker images | grep frontend
```

### Step 2: Tag for ECR

```bash
# Tag image for ECR repository
docker tag frontend:${IMAGE_TAG} \
  108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend:${IMAGE_TAG}

# Also tag as 'latest'
docker tag frontend:${IMAGE_TAG} \
  108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend:latest
```

### Step 3: Push to ECR

```bash
# Ensure ECR login (if not already logged in)
AWS_PROFILE=davidshaevel-dev aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  108581769167.dkr.ecr.us-east-1.amazonaws.com

# Push tagged image
docker push 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend:${IMAGE_TAG}

# Push latest tag
docker push 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend:latest
```

### Step 4: Update Terraform and Deploy

```bash
# Navigate to Terraform environment
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/terraform/environments/dev

# Update frontend_image_tag variable
export TF_VAR_frontend_image_tag=${IMAGE_TAG}

# Deploy
export AWS_PROFILE=davidshaevel-dev
terraform plan
terraform apply
```

### Step 5: Invalidate CloudFront Cache

**CRITICAL:** Frontend changes require CloudFront invalidation to be visible immediately.

```bash
# Get CloudFront distribution ID
AWS_PROFILE=davidshaevel-dev aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='DavidShaevel.com CDN'].Id" \
  --output text

# Create invalidation for all paths
AWS_PROFILE=davidshaevel-dev aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"

# Monitor invalidation progress
AWS_PROFILE=davidshaevel-dev aws cloudfront get-invalidation \
  --distribution-id <distribution-id> \
  --id <invalidation-id>
```

**Expected Duration:** 3-5 minutes for invalidation to complete

### Step 6: Verify Frontend Health

```bash
# Check all frontend endpoints
curl -I https://davidshaevel.com/
curl -I https://davidshaevel.com/about
curl -I https://davidshaevel.com/projects
curl -I https://davidshaevel.com/contact
curl -I https://davidshaevel.com/health

# All should return HTTP/2 200
```

**Browser Verification:**
- Open https://davidshaevel.com in incognito/private window
- Navigate to all pages
- Check browser console for errors
- Verify content updated correctly

---

## Database Migrations

**IMPORTANT:** Always test migrations locally before running in production.

### Testing Migrations Locally

```bash
# Navigate to backend directory
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/backend

# Run migration script locally
node database/run-migration.js \
  --host localhost \
  --port 5432 \
  --database davidshaevel \
  --username postgres \
  --password <local-password> \
  001_initial_schema.sql

# Verify migration succeeded
# Check migration_history table
```

### Running Migrations in Production

```bash
# Get RDS credentials from AWS Secrets Manager
AWS_PROFILE=davidshaevel-dev aws secretsmanager get-secret-value \
  --secret-id dev-davidshaevel-db-credentials \
  --query SecretString \
  --output text

# Extract values from JSON:
# - username
# - password
# - host
# - port
# - dbname

# Run migration (from ECS task or bastion host)
node database/run-migration.js \
  --host <rds-endpoint> \
  --port 5432 \
  --database <dbname> \
  --username <username> \
  --password <password> \
  <migration-file.sql>
```

**Migration Guidelines:**
- All migrations are idempotent (safe to run multiple times)
- All migrations are atomic (wrapped in transactions)
- Migrations are numbered sequentially (001, 002, etc.)
- Migration history tracked in `migration_history` table
- Never modify existing migrations (create new ones)

**Rollback Strategy:**
- Migrations do not have automatic rollback
- Create a new "down" migration if rollback needed
- Test rollback migrations locally first

---

## Health Check Verification

### All Production Endpoints

**Expected Status: All endpoints should return 200 OK**

```bash
# Frontend Pages
curl -I https://davidshaevel.com/          # Homepage
curl -I https://davidshaevel.com/about     # About page
curl -I https://davidshaevel.com/projects  # Projects page
curl -I https://davidshaevel.com/contact   # Contact page
curl -I https://davidshaevel.com/health    # Frontend health check

# Backend API
curl -I https://davidshaevel.com/api/health    # Backend health check
curl -I https://davidshaevel.com/api/projects  # Backend API endpoint
```

### AWS Infrastructure Health Checks

```bash
# Check ECS cluster status
AWS_PROFILE=davidshaevel-dev aws ecs describe-clusters \
  --clusters dev-davidshaevel-cluster

# Expected: status="ACTIVE", runningTasksCount=4 (2 frontend, 2 backend)

# Check ECS services
AWS_PROFILE=davidshaevel-dev aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services backend frontend

# Expected: desiredCount=2, runningCount=2 for each service

# Check ALB target health
AWS_PROFILE=davidshaevel-dev aws elbv2 describe-target-health \
  --target-group-arn <backend-target-group-arn>

AWS_PROFILE=davidshaevel-dev aws elbv2 describe-target-health \
  --target-group-arn <frontend-target-group-arn>

# Expected: all targets in "healthy" state
```

### RDS Database Connectivity

```bash
# From backend container or bastion host
psql -h <rds-endpoint> \
     -p 5432 \
     -U <username> \
     -d <dbname> \
     -c "SELECT 1;"

# Expected: Returns (1 row)
```

### CloudWatch Logs

```bash
# Backend logs
AWS_PROFILE=davidshaevel-dev aws logs tail \
  /ecs/davidshaevel/backend \
  --since 5m

# Frontend logs
AWS_PROFILE=davidshaevel-dev aws logs tail \
  /ecs/davidshaevel/frontend \
  --since 5m

# Look for errors, warnings, or unexpected patterns
```

---

## Rollback Procedures

### Backend Rollback

**Scenario:** New backend deployment is failing health checks or causing errors.

```bash
# 1. Identify previous working image tag
AWS_PROFILE=davidshaevel-dev aws ecr describe-images \
  --repository-name davidshaevel/backend \
  --query 'sort_by(imageDetails,& imagePushedAt)[-5:]' \
  --output table

# 2. Update Terraform with previous image tag
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/terraform/environments/dev

export TF_VAR_backend_image_tag=<previous-working-tag>

# 3. Apply rollback
export AWS_PROFILE=davidshaevel-dev
terraform plan  # Verify it's rolling back to correct image
terraform apply

# 4. Monitor rollback deployment
AWS_PROFILE=davidshaevel-dev aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name backend

# 5. Verify health
curl https://davidshaevel.com/api/health
```

**Rollback Time:** 3-5 minutes (ECS task replacement + health checks)

### Frontend Rollback

```bash
# 1. Identify previous working image tag
AWS_PROFILE=davidshaevel-dev aws ecr describe-images \
  --repository-name davidshaevel/frontend \
  --query 'sort_by(imageDetails,& imagePushedAt)[-5:]' \
  --output table

# 2. Update Terraform with previous image tag
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/terraform/environments/dev

export TF_VAR_frontend_image_tag=<previous-working-tag>

# 3. Apply rollback
export AWS_PROFILE=davidshaevel-dev
terraform plan
terraform apply

# 4. Invalidate CloudFront cache
AWS_PROFILE=davidshaevel-dev aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"

# 5. Verify health (wait 3-5 min for invalidation)
curl https://davidshaevel.com/
```

### Database Migration Rollback

**IMPORTANT:** Database rollbacks require careful planning.

```bash
# 1. Create a "down" migration file
# Example: 003_rollback_002.sql

# 2. Test rollback migration locally first
node database/run-migration.js \
  --host localhost \
  --port 5432 \
  --database davidshaevel \
  --username postgres \
  --password <local-password> \
  003_rollback_002.sql

# 3. Verify local rollback succeeded
# Check schema, data integrity

# 4. Apply rollback to production
node database/run-migration.js \
  --host <rds-endpoint> \
  --port 5432 \
  --database <dbname> \
  --username <username> \
  --password <password> \
  003_rollback_002.sql

# 5. Verify backend still works
curl https://davidshaevel.com/api/health
curl https://davidshaevel.com/api/projects
```

---

## Troubleshooting

### Problem: ECS Tasks Failing to Start

**Symptoms:**
- Tasks transition from PENDING → STOPPED
- Health checks never pass
- Service shows fewer than desired tasks

**Diagnosis:**
```bash
# Check stopped tasks
AWS_PROFILE=davidshaevel-dev aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks <stopped-task-arn>

# Look for:
# - stoppedReason
# - containers[].reason
# - containers[].exitCode
```

**Common Causes:**

1. **Image Pull Failure**
   - Verify ECR image exists: `aws ecr describe-images --repository-name davidshaevel/backend`
   - Verify task role has ECR permissions
   - Check CloudWatch logs for pull errors

2. **Environment Variable Issues**
   - Verify Secrets Manager secret exists and is accessible
   - Check task role has `secretsmanager:GetSecretValue` permission
   - Verify environment variables in task definition

3. **Port Conflicts**
   - Verify container port matches ALB target group port
   - Backend: 3000, Frontend: 3000 (internal), both exposed via ALB

4. **Health Check Failures**
   - Check health check path: `/api/health` (backend), `/health` (frontend)
   - Verify health check interval and timeout values
   - Check CloudWatch logs for application errors

**Resolution:**
```bash
# Fix issue, then force new deployment
AWS_PROFILE=davidshaevel-dev aws ecs update-service \
  --cluster dev-davidshaevel-cluster \
  --service backend \
  --force-new-deployment
```

### Problem: 502 Bad Gateway Errors

**Symptoms:**
- Frontend or API returns 502 errors
- ALB cannot reach backend targets

**Diagnosis:**
```bash
# Check target health
AWS_PROFILE=davidshaevel-dev aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# Check security groups
# Verify ALB security group can reach ECS tasks on port 3000
```

**Common Causes:**

1. **Backend Not Healthy**
   - ECS tasks in RUNNING state but failing health checks
   - Application not listening on correct port (3000)
   - Database connection issues

2. **Security Group Misconfiguration**
   - ECS security group not allowing traffic from ALB
   - Database security group not allowing traffic from ECS

3. **Target Group Health Check Issues**
   - Incorrect health check path
   - Health check timeout too short
   - Application slow to start

**Resolution:**
```bash
# Check backend logs for errors
AWS_PROFILE=davidshaevel-dev aws logs tail \
  /ecs/davidshaevel/backend \
  --follow

# Verify database connectivity from task
# Exec into running task (if needed)
# Check application is listening on 0.0.0.0:3000
```

### Problem: CloudFront Serving Stale Content

**Symptoms:**
- Frontend updates not visible
- Old version still being served
- Cache headers indicate old content

**Diagnosis:**
```bash
# Check CloudFront cache behavior
curl -I https://davidshaevel.com/

# Look for:
# - x-cache: Hit from cloudfront (cached)
# - x-cache: Miss from cloudfront (fresh from origin)
```

**Resolution:**
```bash
# Create invalidation for affected paths
AWS_PROFILE=davidshaevel-dev aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"

# For specific files:
AWS_PROFILE=davidshaevel-dev aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/index.html" "/about.html"

# Monitor invalidation (takes 3-5 minutes)
AWS_PROFILE=davidshaevel-dev aws cloudfront get-invalidation \
  --distribution-id <distribution-id> \
  --id <invalidation-id>
```

### Problem: Database Connection Errors

**Symptoms:**
- Backend health check shows `"database":"disconnected"`
- 500 errors on API endpoints
- TypeORM connection errors in logs

**Diagnosis:**
```bash
# Check RDS instance status
AWS_PROFILE=davidshaevel-dev aws rds describe-db-instances \
  --db-instance-identifier dev-davidshaevel-db

# Verify security group allows ECS → RDS on port 5432

# Check Secrets Manager secret
AWS_PROFILE=davidshaevel-dev aws secretsmanager get-secret-value \
  --secret-id dev-davidshaevel-db-credentials
```

**Common Causes:**

1. **RDS Instance Stopped**
   - Check instance status: `available` vs `stopped`
   - Restart if needed

2. **Security Group Issue**
   - ECS security group not in RDS ingress rules
   - Port 5432 not allowed

3. **Incorrect Credentials**
   - Secrets Manager secret doesn't match RDS password
   - Environment variable misconfiguration

4. **Connection Pool Exhaustion**
   - Too many connections, not being released
   - Check TypeORM connection pool settings

**Resolution:**
```bash
# Restart backend service to reset connections
AWS_PROFILE=davidshaevel-dev aws ecs update-service \
  --cluster dev-davidshaevel-cluster \
  --service backend \
  --force-new-deployment

# Verify backend can connect
curl https://davidshaevel.com/api/health
# Should show "database":"connected"
```

### Problem: Terraform State Lock

**Symptoms:**
- `terraform plan` or `terraform apply` hangs
- Error: "Error acquiring the state lock"

**Diagnosis:**
```bash
# Check DynamoDB for lock table
AWS_PROFILE=davidshaevel-dev aws dynamodb scan \
  --table-name davidshaevel-terraform-locks
```

**Resolution:**
```bash
# Force unlock (ONLY if you're certain no other terraform is running)
terraform force-unlock <lock-id>

# Better: Wait for lock to release naturally
# Check if another terraform process is running
ps aux | grep terraform
```

---

## Emergency Contacts

**Platform Owner:** David Shaevel
**Repository:** https://github.com/davidshaevel-dot-com/davidshaevel-platform
**Linear Project:** DavidShaevel.com Platform Engineering Portfolio

**AWS Resources:**
- Account ID: 108581769167
- Region: us-east-1
- Profile: davidshaevel-dev

**Key Services:**
- ECS Cluster: `dev-davidshaevel-cluster`
- RDS Instance: `dev-davidshaevel-db`
- CloudFront Distribution: (get ID via CLI)
- ECR Repositories: `davidshaevel/backend`, `davidshaevel/frontend`

**Documentation:**
- Main README: [README.md](../README.md)
- Architecture Docs: [terraform/README.md](../terraform/README.md)
- Backend README: [backend/README.md](../backend/README.md)
- Frontend README: [frontend/README.md](../frontend/README.md)

---

## Future Automation (CI/CD)

**Current Status:** Deployments are manual (this runbook)

**Planned:** GitHub Actions CI/CD workflows (Linear issue TT-31)

When CI/CD is implemented, this runbook will still be valuable for:
- Manual emergency deployments
- Rollback procedures
- Troubleshooting deployments
- Understanding deployment process
- Training new team members

**Related Linear Issues:**
- TT-31: Implement GitHub Actions CI/CD workflows (4-6 hours)
- TT-26: Documentation & Demo Materials (includes runbook improvements)

---

**End of Deployment Runbook**
