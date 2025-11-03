# TT-23 Backend Deployment Session Agenda

**Date:** October 29, 2025 (Wednesday)  
**Session:** Backend Deployment to AWS ECS  
**Linear Issue:** [TT-23](https://linear.app/davidshaevel-dot-com/issue/TT-23/deploy-backend-to-ecs-fargate-phase-1-backend-only)  
**Estimated Time:** 3-4 hours

---

## Session Goals

**Primary Goal:** Deploy Nest.js backend API to AWS ECS Fargate and verify production database connectivity.

**Success Criteria:**
- ✅ Backend accessible at `https://davidshaevel.com/api/health`
- ✅ Health endpoint returns 200 OK with database connected
- ✅ Projects CRUD API functional in production
- ✅ CloudWatch logs showing application output
- ✅ Both ECS tasks running and healthy

---

## Prerequisites Completed

- ✅ TT-18: Next.js Frontend complete (PR #14 merged)
- ✅ TT-19: Nest.js Backend complete (PR #15 merged)
- ✅ TT-28: Automated integration tests (PR #16 merged)
- ✅ Infrastructure 100% deployed (VPC, RDS, ECS cluster, ALB, CloudFront)
- ✅ Backend containerized with multi-stage Dockerfile
- ✅ Health and metrics endpoints implemented
- ✅ All 14 automated tests passing

---

## Strategic Context

### Why Backend-First Deployment?

After careful analysis of TT-20 (Local Dev) vs TT-23 (Backend Deploy), the decision was made to deploy backend first:

**Benefits:**
1. ✅ Validate production infrastructure early (RDS, Secrets Manager, security groups)
2. ✅ Portfolio value - live API for job search conversations
3. ✅ De-risks AWS infrastructure before frontend complexity
4. ✅ Enables realistic testing (frontend → deployed backend in TT-20)
5. ✅ Faster time to working demonstration (3-4 hours vs 10+ hours)

**Scope Simplification:**
- Manual deployment only (no GitHub Actions CI/CD)
- Focus on getting backend running in production quickly
- CI/CD automation deferred to future enhancement

---

## Session Plan

### Phase 1: ECR Repository Setup (30 minutes)

**Task 1.1: Create ECR Repository**

**Option A: AWS CLI (Faster - RECOMMENDED)**
```bash
# Verify AWS credentials
aws sts get-caller-identity
aws ecr describe-repositories --region us-east-1

# Create ECR repository
aws ecr create-repository \
  --repository-name davidshaevel/backend \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --region us-east-1 \
  --tags Key=Project,Value=davidshaevel Key=Environment,Value=dev

# Set lifecycle policy (keep last 10 images)
cat > /tmp/ecr-lifecycle-policy.json <<'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name davidshaevel/backend \
  --lifecycle-policy-text file:///tmp/ecr-lifecycle-policy.json \
  --region us-east-1

# Verify repository created
aws ecr describe-repositories \
  --repository-names davidshaevel/backend \
  --region us-east-1
```

**Expected Output:**
```json
{
  "repositories": [
    {
      "repositoryArn": "arn:aws:ecr:us-east-1:108581769167:repository/davidshaevel/backend",
      "repositoryUri": "108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend",
      "imageScanningConfiguration": {
        "scanOnPush": true
      },
      "encryptionConfiguration": {
        "encryptionType": "AES256"
      }
    }
  ]
}
```

**Option B: Terraform (More IaC-aligned)**
- Add ECR resource to compute module
- Apply Terraform changes
- (Defer if time-constrained - use AWS CLI)

---

### Phase 2: Build and Push Backend Image (30 minutes)

**Task 2.1: Build Backend Docker Image**

```bash
# Navigate to backend directory
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/backend

# Verify Dockerfile exists
ls -la Dockerfile

# Build image with latest tag
docker build -t backend:latest .

# Build image with git commit SHA tag
docker build -t backend:$(git rev-parse --short HEAD) .

# Verify images created
docker images | grep backend
```

**Expected Output:**
```
backend   latest   <image-id>   Just now   <size>MB
backend   <sha>    <image-id>   Just now   <size>MB
```

**Task 2.2: Tag Images for ECR**

```bash
# Get ECR repository URI (from Phase 1)
ECR_REPO="108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend"

# Tag latest
docker tag backend:latest $ECR_REPO:latest

# Tag with git SHA
GIT_SHA=$(git rev-parse --short HEAD)
docker tag backend:$GIT_SHA $ECR_REPO:$GIT_SHA

# Verify tags
docker images | grep davidshaevel/backend
```

**Task 2.3: Login to ECR and Push Images**

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  108581769167.dkr.ecr.us-east-1.amazonaws.com

# Push latest tag
docker push $ECR_REPO:latest

# Push git SHA tag
docker push $ECR_REPO:$GIT_SHA

# Verify images in ECR
aws ecr list-images \
  --repository-name davidshaevel/backend \
  --region us-east-1
```

**Expected Output:**
```json
{
  "imageIds": [
    {
      "imageDigest": "sha256:...",
      "imageTag": "latest"
    },
    {
      "imageDigest": "sha256:...",
      "imageTag": "<git-sha>"
    }
  ]
}
```

---

### Phase 3: Update Terraform Configuration (1 hour)

**Task 3.1: Review Current Compute Module Configuration**

```bash
# Navigate to Terraform
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/terraform/environments/dev

# Source environment variables
source ../../../.envrc

# Check current task definition
terraform state show module.compute.aws_ecs_task_definition.backend | grep image
```

**Current State:** `image = "nginx:latest"` (placeholder)

**Task 3.2: Update Backend Image in Terraform**

**Update `terraform/environments/dev/main.tf`:**

Find the compute module block and update the backend_image_uri variable:

```hcl
module "compute" {
  source = "../../modules/compute"
  
  # ... existing configuration ...
  
  # Update backend image from nginx to ECR image
  backend_image_uri = "108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:latest"
  
  # Existing configuration should already have these, but verify:
  backend_cpu    = 512
  backend_memory = 1024
  backend_port   = 3001
  backend_desired_count = 2
}
```

**Task 3.3: Verify Environment Variables Configuration**

The backend needs these environment variables. Check if they're already configured in the compute module:

**Required Environment Variables:**
- `NODE_ENV=production`
- `PORT=3001`
- `FRONTEND_URL=https://davidshaevel.com` (for CORS)

**Required Secrets (from Secrets Manager):**
- `DB_HOST` - RDS endpoint
- `DB_PORT` - 5432
- `DB_NAME` - davidshaevel
- `DB_USERNAME` - dbadmin
- `DB_PASSWORD` - from Secrets Manager

**Check if compute module already handles this:**
```bash
# Look at current task definition
terraform state show module.compute.aws_ecs_task_definition.backend | grep -A 20 container_definitions
```

**Note:** The compute module was created in TT-22 with placeholder images. It should already have secrets integration for database credentials. We need to verify this is configured correctly.

**Task 3.4: Plan and Apply Terraform Changes**

```bash
# Navigate to dev environment
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/terraform/environments/dev

# Source environment variables
source ../../../.envrc

# Verify AWS credentials
aws sts get-caller-identity

# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan changes (should show task definition update)
terraform plan

# Expected changes:
# - module.compute.aws_ecs_task_definition.backend (forces replacement)
# - module.compute.aws_ecs_service.backend (update in-place)

# Apply changes
terraform apply

# Type 'yes' when prompted
```

**Expected Terraform Output:**
```
Plan: 1 to add, 1 to change, 1 to destroy.

Changes:
  # module.compute.aws_ecs_task_definition.backend must be replaced
  ~ image = "nginx:latest" -> "108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:latest"
  
  # module.compute.aws_ecs_service.backend will be updated in-place
  ~ task_definition = "arn:aws:ecs:.../:1" -> "arn:aws:ecs:.../:2"
```

---

### Phase 4: Verification and Testing (1 hour)

**Task 4.1: Monitor ECS Service Deployment**

```bash
# Watch ECS service update
watch -n 5 'aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend \
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount,Events:events[:3]}" \
  --output table'

# Wait for:
# - New tasks to start (RUNNING state)
# - Old tasks to drain (graceful shutdown)
# - Service to reach steady state (runningCount == desiredCount)

# Expected timeline: 2-5 minutes
```

**Task 4.2: Check Task Health**

```bash
# List running tasks
aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-backend \
  --desired-status RUNNING

# Describe tasks (get task ARNs from previous command)
aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks <task-arn-1> <task-arn-2> \
  --query 'tasks[*].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus,Containers:containers[*].{Name:name,Status:lastStatus,Health:healthStatus}}'
```

**Expected:**
- 2 tasks in RUNNING state
- Health status: HEALTHY (after ALB health checks pass)

**Task 4.3: Check ALB Target Health**

```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names dev-davidshaevel-backend \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}'

# Expected: Both targets in "healthy" state
```

**Task 4.4: Test Health Endpoint**

```bash
# Test health endpoint via CloudFront/ALB
curl https://davidshaevel.com/api/health | jq .

# Expected response:
{
  "status": "healthy",
  "timestamp": "2025-10-29T...",
  "version": "1.0.0",
  "service": "backend",
  "uptime": 123.45,
  "environment": "production",
  "database": {
    "status": "connected",
    "type": "postgresql"
  }
}

# If 502 error: Tasks may still be starting or health checks haven't passed yet
# Wait 2-3 minutes and retry
```

**Task 4.5: Test Metrics Endpoint**

```bash
# Test Prometheus metrics endpoint
curl https://davidshaevel.com/api/metrics

# Expected: Prometheus text format
# HELP backend_uptime_seconds Uptime of the backend service in seconds
# TYPE backend_uptime_seconds gauge
# backend_uptime_seconds 123.45
# ...
```

**Task 4.6: Test Projects CRUD API**

```bash
# Test GET all projects (should be empty initially)
curl https://davidshaevel.com/api/projects | jq .

# Expected: []

# Test POST - Create a project
curl -X POST https://davidshaevel.com/api/projects \
  -H "Content-Type: application/json" \
  -d '{
    "title": "DavidShaevel.com Platform",
    "description": "Full-stack AWS portfolio platform demonstrating cloud architecture, infrastructure as code, and modern web development",
    "url": "https://davidshaevel.com",
    "github": "https://github.com/davidshaevel-dot-com/davidshaevel-platform",
    "technologies": ["AWS", "ECS Fargate", "RDS PostgreSQL", "Terraform", "Next.js", "Nest.js", "TypeScript", "Docker", "CloudFront"]
  }' | jq .

# Expected response: Created project with ID
{
  "id": "<uuid>",
  "title": "DavidShaevel.com Platform",
  "description": "...",
  "url": "https://davidshaevel.com",
  "github": "...",
  "technologies": ["AWS", "ECS Fargate", ...],
  "createdAt": "2025-10-29T...",
  "updatedAt": "2025-10-29T..."
}

# Test GET single project
PROJECT_ID="<uuid-from-create>"
curl https://davidshaevel.com/api/projects/$PROJECT_ID | jq .

# Expected: Same project data

# Test PUT - Update project
curl -X PUT https://davidshaevel.com/api/projects/$PROJECT_ID \
  -H "Content-Type: application/json" \
  -d '{
    "title": "DavidShaevel.com Platform (Updated)",
    "description": "Updated description"
  }' | jq .

# Expected: Updated project

# Test GET all projects again
curl https://davidshaevel.com/api/projects | jq .

# Expected: Array with one project

# Test DELETE
curl -X DELETE https://davidshaevel.com/api/projects/$PROJECT_ID -v

# Expected: 204 No Content

# Verify deleted
curl https://davidshaevel.com/api/projects | jq .

# Expected: []
```

**Task 4.7: Check CloudWatch Logs**

```bash
# Tail backend logs
aws logs tail /ecs/dev-davidshaevel-backend --follow

# Look for:
# ✅ "🚀 Backend API running on port 3001"
# ✅ Database connection messages
# ✅ Health check requests (GET /api/health)
# ✅ API requests (POST /api/projects, etc.)
# ❌ Any errors or warnings

# Press Ctrl+C to stop tailing
```

---

### Phase 5: Documentation (1 hour)

**Task 5.1: Update Root README.md**

Add "Production Deployment" section:

```markdown
## Production Deployment

### Backend API

**Live Endpoints:**
- Health: https://davidshaevel.com/api/health
- Metrics: https://davidshaevel.com/api/metrics
- Projects API: https://davidshaevel.com/api/projects

**Infrastructure:**
- Platform: AWS ECS Fargate
- Container Registry: Amazon ECR
- Database: Amazon RDS PostgreSQL 15.12
- Load Balancer: Application Load Balancer
- CDN: Amazon CloudFront
- Monitoring: CloudWatch Logs

**Deployment Status:** ✅ Backend deployed and operational
```

**Task 5.2: Update backend/README.md**

Add "AWS Deployment" section with:
- ECR repository information
- Image build and push instructions
- Environment variables in production
- CloudWatch logs access
- Troubleshooting guide

**Task 5.3: Create Backend Deployment Guide**

Create `docs/2025-10-29_backend_deployment_guide.md` with:
- Step-by-step deployment process
- ECR setup instructions
- Docker build and push commands
- Terraform configuration changes
- Verification steps
- Troubleshooting common issues

**Task 5.4: Update AGENT_HANDOFF.md**

Add TT-23 completion section:
- Deployment date and status
- ECR repository URI
- Backend endpoint URLs
- CloudWatch log group
- Lessons learned
- Next steps (TT-20)

---

## Troubleshooting Guide

### Issue: Tasks fail to start

**Symptoms:**
- ECS tasks in STOPPED state
- Tasks fail shortly after starting

**Diagnosis:**
```bash
# Check stopped tasks
aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-backend \
  --desired-status STOPPED

# Describe stopped task (get ARN from above)
aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks <stopped-task-arn> \
  --query 'tasks[0].{StopCode:stopCode,StopReason:stoppedReason,Containers:containers[*].{Reason:reason,ExitCode:exitCode}}'
```

**Common Causes:**
1. **Image pull error** - ECR permissions or image doesn't exist
2. **Container crash** - Application error on startup
3. **Environment variables** - Missing or incorrect configuration
4. **Secrets Manager** - Can't retrieve database credentials

**Solutions:**
```bash
# Verify ECR image exists
aws ecr describe-images \
  --repository-name davidshaevel/backend \
  --region us-east-1

# Check CloudWatch logs for application errors
aws logs tail /ecs/dev-davidshaevel-backend --since 10m

# Verify Secrets Manager permissions
aws iam get-role-policy \
  --role-name <task-execution-role> \
  --policy-name <secrets-policy>
```

### Issue: Health checks fail

**Symptoms:**
- Targets show "unhealthy" in target group
- 502 errors when accessing API
- Tasks running but not receiving traffic

**Diagnosis:**
```bash
# Check target health details
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN

# Check health check configuration
aws elbv2 describe-target-groups \
  --target-group-arns $TG_ARN \
  --query 'TargetGroups[0].{Path:HealthCheckPath,Port:HealthCheckPort,Protocol:HealthCheckProtocol}'
```

**Common Causes:**
1. **Wrong health check path** - Should be `/api/health`
2. **Backend not listening on port 3001**
3. **Database connection failing**
4. **Security group blocking ALB → ECS**

**Solutions:**
```bash
# Verify backend is listening
aws logs tail /ecs/dev-davidshaevel-backend --since 5m | grep "running on port"

# Check security groups
aws ec2 describe-security-groups \
  --group-ids <ecs-security-group-id> \
  --query 'SecurityGroups[0].IpPermissions[*].{FromPort:FromPort,ToPort:ToPort,Source:IpRanges}'

# Test health endpoint from within VPC (if you have bastion host)
# Or check CloudWatch logs for health check requests
```

### Issue: Database connection fails

**Symptoms:**
- Health endpoint returns "unhealthy" with database: "error"
- CloudWatch logs show database connection errors
- Tasks crash with "ECONNREFUSED" or "ETIMEDOUT"

**Diagnosis:**
```bash
# Check RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier davidshaevel-dev-db \
  --query 'DBInstances[0].{Endpoint:Endpoint.Address,Port:Endpoint.Port,Status:DBInstanceStatus}'

# Check Secrets Manager secret
aws secretsmanager get-secret-value \
  --secret-id <secret-arn> \
  --query SecretString --output text | jq .
```

**Common Causes:**
1. **RDS security group** - Not allowing ECS security group
2. **Wrong database credentials** - Secrets Manager misconfigured
3. **Task execution role** - Can't read Secrets Manager
4. **Database not in same VPC** - Network routing issue

**Solutions:**
```bash
# Update RDS security group to allow ECS
aws ec2 authorize-security-group-ingress \
  --group-id <rds-security-group-id> \
  --protocol tcp \
  --port 5432 \
  --source-group <ecs-security-group-id>

# Verify task execution role has Secrets Manager permissions
aws iam get-role-policy \
  --role-name <task-execution-role> \
  --policy-name SecretsManagerAccess
```

---

## Success Metrics

**Deployment Success:**
- ✅ Backend deploys on first terraform apply
- ✅ 2 ECS tasks reach RUNNING state
- ✅ Health checks pass within 5 minutes
- ✅ All API endpoints return expected responses

**Performance:**
- ✅ Health endpoint < 200ms response time
- ✅ Projects API < 500ms response time
- ✅ Database queries < 100ms

**Reliability:**
- ✅ Both tasks healthy for 10+ minutes
- ✅ Zero 5xx errors
- ✅ Database connection stable

---

## Expected Timeline

| Phase | Task | Duration | Start | End |
|-------|------|----------|-------|-----|
| 1 | ECR Repository Setup | 30 min | 0:00 | 0:30 |
| 2 | Build and Push Image | 30 min | 0:30 | 1:00 |
| 3 | Terraform Configuration | 1 hour | 1:00 | 2:00 |
| 4 | Verification and Testing | 1 hour | 2:00 | 3:00 |
| 5 | Documentation | 1 hour | 3:00 | 4:00 |
| **Total** | | **4 hours** | | |

**Buffer:** 30-60 minutes for troubleshooting if needed

---

## Deliverables Checklist

### Technical Deliverables
- [ ] ECR repository created with lifecycle policy
- [ ] Backend Docker image built and pushed to ECR (2 tags: latest + git SHA)
- [ ] Terraform configuration updated with ECR image URI
- [ ] ECS service deployed with new backend image
- [ ] 2 ECS tasks running and healthy
- [ ] ALB targets healthy (both tasks)
- [ ] Health endpoint accessible and returning database status
- [ ] Metrics endpoint returning Prometheus format
- [ ] Projects CRUD API fully functional
- [ ] CloudWatch logs showing application output

### Documentation Deliverables
- [ ] Root README.md updated with production deployment section
- [ ] backend/README.md updated with AWS deployment guide
- [ ] Backend deployment guide created (docs/2025-10-29_backend_deployment_guide.md)
- [ ] AGENT_HANDOFF.md updated with TT-23 completion details
- [ ] Session summary created

### Testing Deliverables
- [ ] Health endpoint tested (200 OK, database connected)
- [ ] Metrics endpoint tested (Prometheus format)
- [ ] Projects API tested (GET, POST, PUT, DELETE)
- [ ] Database persistence verified
- [ ] CloudWatch logs reviewed (no errors)
- [ ] Performance metrics validated

---

## Post-Session Actions

1. **Update Linear Issue TT-23** - Mark as Done
2. **Create session summary** - Document what was accomplished
3. **Update Linear TT-20** - Add notes about testing against deployed backend
4. **Commit all documentation changes** to a feature branch
5. **Create pull request** for documentation updates
6. **Post project update** to Linear project

---

## Notes for Next Session (TT-20)

After TT-23 completes, TT-20 gains new capabilities:

**Testing Against Deployed Backend:**
- Frontend can make API calls to https://davidshaevel.com/api/
- Validate CORS configuration end-to-end
- Test with real production database
- More realistic testing environment

**Docker Compose Configuration:**
- Can configure frontend to point to either localhost:3001 or davidshaevel.com
- Test both local backend and remote backend scenarios
- Validate environment variable configuration

**Documentation Reference:**
- Use deployed backend as reference implementation
- Document differences between local and production
- Troubleshooting guide based on actual production experience

---

## References

- **Linear Issue TT-23:** https://linear.app/davidshaevel-dot-com/issue/TT-23
- **Deployment Strategy Analysis:** `docs/2025-10-29_deployment_strategy_analysis.md`
- **Backend README:** `backend/README.md`
- **Terraform Compute Module:** `terraform/modules/compute/`
- **AGENT_HANDOFF:** `.claude/AGENT_HANDOFF.md`

---

**Status:** Ready to begin  
**Environment:** AWS (davidshaevel-dev profile, us-east-1)  
**Git Branch:** Will create `david/tt-23-backend-deployment-to-ecs`

