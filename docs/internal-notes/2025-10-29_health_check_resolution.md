# Health Check Resolution - Backend ECS Deployment

**Date:** October 29, 2025  
**Issue:** ECS tasks continuously restarting due to failed health checks  
**Status:** ✅ **RESOLVED**

---

## Problem Description

After deploying the backend to ECS, tasks were showing as UNHEALTHY and were being continuously stopped and restarted by ECS. The service was unstable despite the application running correctly.

### Symptoms
- Tasks constantly being deprovisioned, stopped, and restarted
- Health status: UNHEALTHY in AWS Console
- Target group health checks failing
- Service unable to reach stable state

---

## Root Causes Identified

### Issue 1: Incorrect Health Check Paths

**Problem:** Health checks were hitting wrong endpoints

**ALB Target Group:**
- Configured path: `/health`
- Correct path: `/api/health`
- Result: 404 Not Found

**ECS Container Health Check:**
- Configured command: `curl -f http://localhost:3001/health`
- Correct command: `curl -f http://localhost:3001/api/health`
- Result: 404 Not Found

**Why:** Backend serves all endpoints under `/api/*` prefix due to global prefix configuration in `main.ts`:
```typescript
app.setGlobalPrefix('api');
```

### Issue 2: Missing `curl` in Docker Image

**Problem:** ECS health check command failed to execute

**Container Health Check Command:**
```bash
curl -f http://localhost:3001/api/health || exit 1
```

**Error:** `curl: not found`

**Why:** Base image `node:20-alpine` is minimal Alpine Linux which doesn't include `curl` by default.

---

## Solutions Implemented

### Fix 1: Update Health Check Paths (Terraform)

**File:** `terraform/modules/compute/variables.tf`
```terraform
variable "backend_health_check_path" {
  description = "Health check path for backend service"
  type        = string
  default     = "/api/health"  # Was: "/health"
}
```

**File:** `terraform/modules/compute/main.tf`
```terraform
healthCheck = {
  command = ["CMD-SHELL", "curl -f http://localhost:${local.backend_port}/api/health || exit 1"]
  # Was: /health
}
```

**Applied:** Terraform changes created new task definition (revision 4)

### Fix 2: Update Target Group Health Check (Manual)

Since Terraform didn't detect the drift, manually updated via AWS CLI:
```bash
aws elbv2 modify-target-group \
  --target-group-arn <arn> \
  --health-check-path /api/health
```

### Fix 3: Install `curl` in Docker Image

**File:** `backend/Dockerfile`
```dockerfile
# Stage 3: Runner
FROM node:20-alpine AS runner
WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# ... rest of Dockerfile
```

**Impact:** Adds ~2MB to image size but enables ECS health checks

---

## Verification

### Before Fixes
```bash
$ aws ecs describe-tasks ...
HealthStatus: UNHEALTHY
ContainerHealth: UNHEALTHY

$ aws elbv2 describe-target-health ...
HealthStatus: unhealthy
Reason: Target.FailedHealthChecks
```

### After Fixes
```bash
$ aws ecs describe-services --cluster dev-davidshaevel-cluster \
    --services dev-davidshaevel-backend
DesiredCount: 2
RunningCount: 2
PendingCount: 0

$ aws ecs describe-tasks ... (both tasks)
HealthStatus: HEALTHY ✅
ContainerHealth: HEALTHY ✅

$ aws elbv2 describe-target-health ...
HealthStatus: healthy ✅
Reason: None

$ curl -s https://davidshaevel.com/api/health
{
  "status": "healthy",
  "database": {
    "status": "connected",
    "type": "postgresql"
  }
}
```

---

## Git Commits

1. **b25f50c** - `fix(terraform): correct health check paths for backend API`
   - Updated health check paths from `/health` to `/api/health`
   - Fixed both container and target group health checks

2. **23f5978** - `fix(backend): install curl for ECS health checks`
   - Added `curl` to Alpine image for health check execution
   - Minimal overhead, maximum compatibility

---

## Lessons Learned

### 1. Always Match Health Check Paths to Application Routes
When using global prefixes or route prefixes, ensure health check paths match exactly. A mismatch causes immediate health check failures.

### 2. Alpine Images Are Minimal - Add What You Need
Alpine Linux base images don't include standard utilities like `curl`. Always verify health check commands have required dependencies.

### 3. Container vs. Target Group Health Checks
ECS uses **both** health checks:
- **Container health check:** Determines if container is healthy inside the task
- **Target group health check:** Determines if ALB can route traffic to the task

Both must pass for stable deployment.

### 4. Health Check Grace Period Is Critical
```terraform
health_check_grace_period_seconds = 60  # Give app time to start
```
Without grace period, tasks can be killed during startup before they're ready.

### 5. Terraform State Drift
Target group wasn't shown in `terraform plan` because the actual AWS resource had drifted from Terraform's expected state. Sometimes manual fixes are needed, then import the state.

---

## Configuration Summary

### Working Health Check Configuration

**Docker HEALTHCHECK (native):**
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/api/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"
```

**ECS Container Health Check:**
```json
{
  "command": ["CMD-SHELL", "curl -f http://localhost:3001/api/health || exit 1"],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 60
}
```

**ALB Target Group Health Check:**
```
Path: /api/health
Interval: 30s
Timeout: 5s
Healthy threshold: 2
Unhealthy threshold: 2
```

---

## Final Status

✅ **All health checks passing**  
✅ **2/2 tasks running and healthy**  
✅ **Service stable - no restart loops**  
✅ **API accessible via https://davidshaevel.com/api/**  
✅ **Database connection verified**  

**Deployment:** Revision 4 with corrected health checks  
**Image Tag:** `23f5978` (with curl installed)  
**Related Linear Issue:** TT-23

