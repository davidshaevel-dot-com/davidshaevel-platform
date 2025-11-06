# CI/CD Troubleshooting Guide

Comprehensive troubleshooting guide for GitHub Actions CI/CD workflows.

## Table of Contents

1. [Workflow Failures](#workflow-failures)
2. [Build Failures](#build-failures)
3. [Deployment Failures](#deployment-failures)
4. [Service Health Issues](#service-health-issues)
5. [Monitoring and Debugging](#monitoring-and-debugging)

---

## Workflow Failures

### Workflow Not Triggering

**Symptoms:**
- Push to `main` doesn't trigger workflow
- No workflow runs appear in Actions tab

**Diagnosis:**
```bash
# Check recent pushes
git log --oneline -5

# Check if path matches workflow trigger
# Backend: changes in backend/**
# Frontend: changes in frontend/**

# View workflow file
cat .github/workflows/backend-deploy.yml | grep -A 5 "on:"
```

**Common Causes:**

1. **Path filter mismatch:**
   - Changed files outside `backend/**` or `frontend/**`
   - Workflow only triggers for changes in specific paths

2. **Workflow file syntax error:**
   ```bash
   # Validate workflow syntax (unofficial tool)
   gh workflow list
   ```

3. **Concurrent deployment prevention:**
   - Another deployment already running
   - Check: `gh run list --workflow=backend-deploy.yml --limit 3`
   - Workflows queue automatically (not an error)

**Solutions:**

```bash
# Manually trigger workflow
gh workflow run backend-deploy.yml --field environment=dev

# Force trigger by changing file in correct path
echo "# trigger" >> backend/README.md
git add backend/README.md
git commit -m "chore: trigger CI/CD"
git push origin main
```

---

### ECR Authentication Failures

**Symptoms:**
```
Error: no basic auth credentials
Error: denied: User: arn:aws:iam::xxx:user/xxx is not authorized
```

**Diagnosis:**
```bash
# Verify secrets exist
gh secret list --env dev

# Check IAM user exists
aws iam get-user --user-name dev-davidshaevel-github-actions

# Check IAM policy attached
aws iam list-attached-user-policies \
  --user-name dev-davidshaevel-github-actions
```

**Common Causes:**

1. **Missing or incorrect GitHub secrets:**
   - `AWS_ACCESS_KEY_ID` not set
   - `AWS_SECRET_ACCESS_KEY` not set
   - Values copied incorrectly (trailing spaces, etc.)

2. **IAM credentials invalid:**
   - Access key deleted or deactivated
   - IAM user deleted
   - Credentials expired

3. **IAM policy insufficient:**
   - Missing `ecr:GetAuthorizationToken` permission
   - Policy not attached to user

**Solutions:**

```bash
# Recreate access keys
aws iam create-access-key --user-name dev-davidshaevel-github-actions

# Update GitHub secrets
gh secret set AWS_ACCESS_KEY_ID --env dev
gh secret set AWS_SECRET_ACCESS_KEY --env dev

# Verify IAM policy includes ECR permissions
aws iam get-policy-version \
  --policy-arn arn:aws:iam::108581769167:policy/dev-davidshaevel-github-actions-policy \
  --version-id v1 \
  --query 'PolicyVersion.Document'
```

---

### Docker Build Failures

**Symptoms:**
```
Error: failed to solve: process "/bin/sh -c npm ci" did not complete successfully
Error: ERROR [internal] load metadata for docker.io/library/node:20-alpine
```

**Diagnosis:**
```bash
# Build locally to reproduce
cd backend/  # or frontend/
docker build -t test:local .

# Check Dockerfile syntax
cat Dockerfile

# Check package files exist
ls -la package.json package-lock.json
```

**Common Causes:**

1. **npm install failures:**
   - `package-lock.json` out of sync
   - Private package dependencies
   - Network issues during build

2. **Build timeouts:**
   - Large dependencies
   - Slow network connection in runner

3. **Base image unavailable:**
   - Docker Hub rate limits
   - Image tag doesn't exist

**Solutions:**

```bash
# Update package-lock.json
cd backend/
rm -rf node_modules package-lock.json
npm install
git add package-lock.json
git commit -m "chore: update package-lock.json"
git push

# Test build locally first
docker build --no-cache -t test:local .

# Check for base image
docker pull node:20-alpine
```

---

## Build Failures

### Linting Errors

**Symptoms:**
```
Error: ESLint found X errors
/path/to/file.ts: error  'variable' is assigned a value but never used
```

**Diagnosis:**
```bash
# Run linter locally
cd backend/  # or frontend/
npm run lint

# Fix auto-fixable issues
npm run lint -- --fix
```

**Common Causes:**

1. **Code quality issues:**
   - Unused variables
   - Missing semicolons
   - Incorrect formatting

2. **ESLint configuration changed:**
   - New rules added
   - Rule severity increased

**Solutions:**

```bash
# Fix automatically where possible
npm run lint -- --fix

# Commit fixes
git add .
git commit -m "fix: resolve linting errors"
git push

# Disable specific rules (if appropriate)
# Edit .eslintrc.json or .eslintrc.js
```

---

### Test Failures

**Symptoms:**
```
Error: Test suite failed to run
FAIL src/example/example.spec.ts
  ● Example test › should pass
    expect(received).toBe(expected)
```

**Diagnosis:**
```bash
# Run tests locally
cd backend/
npm run test

# Run specific test file
npm run test -- src/example/example.spec.ts

# Run with verbose output
npm run test -- --verbose
```

**Common Causes:**

1. **Breaking changes:**
   - Code changed but tests not updated
   - Test expectations outdated

2. **Environment differences:**
   - Different Node.js version
   - Missing test dependencies

**Solutions:**

```bash
# Update tests to match new behavior
# Edit test files in src/**/*.spec.ts

# Ensure dependencies installed
npm ci

# Run tests before pushing
npm run test
```

---

## Deployment Failures

### ECS Service Won't Stabilize

**Symptoms:**
```
Error: Timeout after 10 minutes waiting for service stability
Error: ECS service has not stabilized
```

**Diagnosis:**
```bash
# Check service status
aws ecs describe-services \
  --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend

# List tasks
aws ecs list-tasks \
  --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-backend

# Describe failed tasks
aws ecs describe-tasks \
  --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --tasks <task-arn>

# Check CloudWatch logs
aws logs tail /ecs/dev-davidshaevel/backend --since 10m
```

**Common Causes:**

1. **Application crashes on startup:**
   - Database connection failures
   - Missing environment variables
   - Configuration errors

2. **Health check failures:**
   - `/api/health` endpoint not responding
   - Health check timeout too short
   - Application takes too long to start

3. **Resource constraints:**
   - Insufficient CPU or memory
   - Tasks being killed by ECS

**Solutions:**

```bash
# Check task stopped reason
aws ecs describe-tasks ... | jq '.tasks[].stoppedReason'

# Common stopped reasons:
# - "Essential container in task exited" → App crashed
# - "Task failed ELB health checks" → Health endpoint not responding
# - "CannotPullContainerError" → ECR image not found

# View application logs for crash details
aws logs tail /ecs/dev-davidshaevel/backend --since 30m --follow

# Rollback to previous working version
aws ecs update-service \
  --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --service dev-davidshaevel-backend \
  --task-definition dev-davidshaevel-backend:42
```

---

### Task Definition Update Failures

**Symptoms:**
```
Error: An error occurred (InvalidParameterException) when calling RegisterTaskDefinition
Error: Container.image should not be blank
```

**Diagnosis:**
```bash
# Check workflow logs for image URI
gh run view <run-id> --log

# Verify ECR image exists
aws ecr describe-images \
  --profile davidshaevel-dev \
  --repository-name davidshaevel/backend \
  --image-ids imageTag=<git-sha>
```

**Common Causes:**

1. **Image not found:**
   - ECR push failed
   - Image tag mismatch
   - Wrong repository

2. **Task definition invalid:**
   - Required fields missing
   - Invalid JSON format
   - Incompatible parameter combinations

**Solutions:**

```bash
# Verify image pushed successfully
aws ecr list-images \
  --profile davidshaevel-dev \
  --repository-name davidshaevel/backend \
  --max-items 10

# Check workflow "Build & Push" job succeeded
gh run view <run-id>
```

---

## Service Health Issues

### Health Check Endpoint Not Responding

**Symptoms:**
- ALB target health checks failing
- 503 errors from CloudFront/ALB
- Tasks repeatedly restarting

**Diagnosis:**
```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --profile davidshaevel-dev \
  --target-group-arn <arn>

# Check health endpoint directly (if possible)
# Get task private IP
aws ecs describe-tasks ... | jq '.tasks[].containers[].networkInterfaces[].privateIpV4Address'

# Test from within VPC (e.g., bastion host)
curl http://<task-private-ip>:3001/api/health
```

**Common Causes:**

1. **Application not listening on correct port:**
   - Port mismatch between Dockerfile EXPOSE and app.listen()
   - Container port vs host port confusion

2. **Health endpoint broken:**
   - Route not registered
   - Database connection check failing
   - Timeout too short

3. **Network configuration:**
   - Security group blocking traffic
   - ALB to ECS connectivity issue

**Solutions:**

```bash
# Check application logs for startup
aws logs tail /ecs/dev-davidshaevel/backend --since 10m

# Look for:
# - "🚀 Backend API running on port 3001"
# - Database connection success
# - No uncaught exceptions

# Test health endpoint from container
aws ecs execute-command \
  --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --task <task-id> \
  --container backend \
  --interactive \
  --command "/bin/sh"

# Inside container:
curl localhost:3001/api/health
```

---

### Database Connection Issues

**Symptoms:**
```
Error: connect ECONNREFUSED
Error: password authentication failed for user "xxx"
Error: no pg_hba.conf entry for host "xxx"
```

**Diagnosis:**
```bash
# Check RDS instance status
aws rds describe-db-instances \
  --profile davidshaevel-dev \
  --db-instance-identifier dev-davidshaevel-db

# Verify security group allows ECS task connections
aws ec2 describe-security-groups \
  --profile davidshaevel-dev \
  --group-ids <db-security-group-id>

# Check database credentials in Secrets Manager
aws secretsmanager get-secret-value \
  --profile davidshaevel-dev \
  --secret-id dev-davidshaevel-db-secret
```

**Common Causes:**

1. **Credentials incorrect:**
   - Password changed but not updated in app
   - Wrong username
   - Secret not accessible to ECS task

2. **Network connectivity:**
   - Security group not allowing ECS → RDS
   - RDS in wrong subnet
   - Network ACLs blocking traffic

3. **RDS instance issues:**
   - Instance stopped
   - Instance rebooting
   - Storage full

**Solutions:**

```bash
# Verify ECS task can access Secrets Manager
aws iam get-role-policy \
  --profile davidshaevel-dev \
  --role-name dev-davidshaevel-backend-task-role \
  --policy-name SecretsManagerAccess

# Test database connectivity from ECS task
# Use ECS Exec to connect to running task
aws ecs execute-command ... --command "nc -zv <rds-endpoint> 5432"

# Check application database connection config
# View CloudWatch logs for connection attempts
aws logs tail /ecs/dev-davidshaevel/backend --filter-pattern "database"
```

---

## Monitoring and Debugging

### Viewing Workflow Logs

```bash
# List recent runs
gh run list --workflow=backend-deploy.yml --limit 10

# View specific run
gh run view <run-id>

# View logs for failed jobs only
gh run view <run-id> --log-failed

# Download all logs
gh run download <run-id>
```

### Real-Time Log Monitoring

```bash
# Tail backend logs
aws logs tail /ecs/dev-davidshaevel/backend --since 10m --follow

# Tail frontend logs
aws logs tail /ecs/dev-davidshaevel/frontend --since 10m --follow

# Filter for errors only
aws logs tail /ecs/dev-davidshaevel/backend --since 30m --filter-pattern ERROR
```

### ECS Service Debugging

```bash
# Get service events (recent deployments, errors)
aws ecs describe-services \
  --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend \
  --query 'services[0].events[0:10]'

# Get task definition details
aws ecs describe-task-definition \
  --profile davidshaevel-dev \
  --task-definition dev-davidshaevel-backend

# List task failures
aws ecs describe-tasks \
  --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --tasks $(aws ecs list-tasks --cluster dev-davidshaevel-cluster --desired-status STOPPED --max-items 5 --query 'taskArns' --output text)
```

### CloudWatch Metrics

```bash
# View ECS service CPU utilization
aws cloudwatch get-metric-statistics \
  --profile davidshaevel-dev \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=dev-davidshaevel-backend Name=ClusterName,Value=dev-davidshaevel-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# View ALB target health count
aws cloudwatch get-metric-statistics \
  --profile davidshaevel-dev \
  --namespace AWS/ApplicationELB \
  --metric-name HealthyHostCount \
  --dimensions Name=TargetGroup,Value=<target-group-arn> Name=LoadBalancer,Value=<alb-arn> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average
```

---

## Quick Diagnostic Commands

### Full Health Check

```bash
#!/bin/bash
# health-check.sh - Quick system health check

echo "=== Workflow Status ==="
gh run list --workflow=backend-deploy.yml --limit 3
gh run list --workflow=frontend-deploy.yml --limit 3

echo -e "\n=== ECS Service Status ==="
aws ecs describe-services --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend dev-davidshaevel-frontend \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table

echo -e "\n=== ALB Target Health ==="
# Get backend target group health
BACKEND_TG_ARN=$(aws ecs describe-services --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend \
  --query 'services[0].loadBalancers[0].targetGroupArn' \
  --output text)
aws elbv2 describe-target-health --profile davidshaevel-dev \
  --target-group-arn "$BACKEND_TG_ARN" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

# Get frontend target group health
FRONTEND_TG_ARN=$(aws ecs describe-services --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-frontend \
  --query 'services[0].loadBalancers[0].targetGroupArn' \
  --output text)
aws elbv2 describe-target-health --profile davidshaevel-dev \
  --target-group-arn "$FRONTEND_TG_ARN" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

echo -e "\n=== Application Health Endpoints ==="
curl -s -o /dev/null -w "Frontend: %{http_code}\n" https://davidshaevel.com/health
curl -s -o /dev/null -w "Backend: %{http_code}\n" https://davidshaevel.com/api/health

echo -e "\n=== Recent Errors in Logs ==="
aws logs tail /ecs/dev-davidshaevel/backend --profile davidshaevel-dev --since 10m --filter-pattern ERROR | head -20
```

---

## Getting Help

If troubleshooting doesn't resolve the issue:

1. **Check workflow run details:** `gh run view <run-id> --log-failed`
2. **Check application logs:** `aws logs tail ... --since 30m`
3. **Check ECS events:** Service events show deployment history
4. **Review recent changes:** `git log --oneline -10`
5. **Rollback if needed:** Use previous task definition or revert commit

---

**Document Version:** 1.0  
**Last Updated:** November 6, 2025  
**See Also:**  
- [deployment-runbook.md](deployment-runbook.md)  
- [github-secrets-setup.md](github-secrets-setup.md)
