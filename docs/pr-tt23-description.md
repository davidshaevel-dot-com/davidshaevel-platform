# Deploy Nest.js Backend API to AWS ECS Fargate (TT-23)

## 🎉 Summary

Successfully deployed the Nest.js backend API to AWS ECS Fargate with full production configuration. The backend is now live and serving requests at **https://davidshaevel.com/api/**.

**Status:** ✅ **Deployment Complete - All Systems Healthy**

---

## What Was Deployed

### Infrastructure (Terraform)
- **ECR Repositories:** Backend and frontend container registries with image scanning and lifecycle policies
- **ECS Service:** 2 Fargate tasks running the Nest.js backend API
- **Health Checks:** Both ALB target group and ECS container health checks configured and passing
- **Database Connection:** Backend connected to RDS PostgreSQL 15 with SSL/TLS encryption

### Application
- **Backend API:** Nest.js 10 with TypeScript 5
- **Endpoints:**
  - `GET /api/health` - Health check with database status
  - `GET /api/metrics` - Prometheus-compatible metrics
  - `GET /api/projects` - Projects CRUD API (schema pending)
- **Docker Image:** Multi-stage optimized build (218MB)
- **Environment:** Production mode with SSL enabled for RDS

---

## Critical Issues Resolved

### 1. RDS SSL Connection Requirement ✅
**Problem:**
```
error: no pg_hba.conf entry for host "10.0.x.x", user "dbadmin", database "davidshaevel", no encryption
```

**Root Cause:** AWS RDS requires SSL/TLS for all database connections, but TypeORM wasn't configured for SSL.

**Solution:**
- Added SSL configuration to TypeORM in `backend/src/app.module.ts`
- Set `NODE_ENV=production` in ECS task definition to enable SSL
- Connection now uses encrypted TLS transport

**Commits:** `7a95e88`, `b9a00da`

---

### 2. Health Check Path Mismatch ✅
**Problem:** ECS tasks continuously restarting with "UNHEALTHY" status despite application running correctly.

**Root Cause:** Health checks hitting `/health` but backend serves all endpoints under `/api/*` prefix.

**Solution:**
- Updated ALB target group health check path: `/health` → `/api/health`
- Updated ECS container health check path: `/health` → `/api/health`
- Fixed in both Terraform configuration and manually via AWS CLI

**Commits:** `b25f50c`

---

### 3. Missing curl in Docker Image ✅
**Problem:** Container health check command failed to execute:
```
/bin/sh: curl: not found
```

**Root Cause:** Alpine Linux base image (`node:20-alpine`) doesn't include `curl` by default.

**Solution:**
- Added `RUN apk add --no-cache curl` to Dockerfile
- Minimal overhead (~2MB) for critical health check functionality
- Both Docker HEALTHCHECK and ECS health checks now work

**Commits:** `23f5978`

---

## Verification

### Health Endpoint
```bash
$ curl -s https://davidshaevel.com/api/health | jq .
{
  "status": "healthy",
  "timestamp": "2025-10-29T20:51:37.578Z",
  "version": "1.0.0",
  "service": "backend",
  "uptime": 78.682,
  "environment": "production",
  "database": {
    "status": "connected",
    "type": "postgresql"
  }
}
```

### Metrics Endpoint
```bash
$ curl -s https://davidshaevel.com/api/metrics | head -8
# HELP backend_uptime_seconds Application uptime in seconds
# TYPE backend_uptime_seconds counter
backend_uptime_seconds 68.308

# HELP backend_info Backend application information
# TYPE backend_info gauge
backend_info{version="1.0.0",environment="production"} 1
```

### ECS Service Status
```bash
$ aws ecs describe-services --cluster dev-davidshaevel-cluster \
    --services dev-davidshaevel-backend
DesiredCount: 2
RunningCount: 2
PendingCount: 0
Status: ACTIVE ✅
```

### Task Health Status
```bash
$ aws ecs describe-tasks ... (both tasks)
HealthStatus: HEALTHY ✅
ContainerHealth: HEALTHY ✅
```

### Target Group Health
```bash
$ aws elbv2 describe-target-health --target-group-arn <arn>
Target 1: healthy ✅
Target 2: healthy ✅
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CloudFront CDN                         │
│                 davidshaevel.com (HTTPS)                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                Application Load Balancer                    │
│              dev-davidshaevel-alb (HTTP)                    │
└───────┬──────────────────────────────────────────┬──────────┘
        │                                          │
        ▼                                          ▼
┌──────────────────┐                    ┌──────────────────────┐
│  ECS Frontend    │                    │    ECS Backend       │
│  (nginx:latest)  │                    │  (Nest.js + Node20)  │
│  2 tasks         │                    │  2 tasks ✅ HEALTHY  │
│  Port: 3000      │                    │  Port: 3001          │
└──────────────────┘                    └──────┬───────────────┘
                                               │ SSL/TLS
                                               ▼
                                    ┌─────────────────────────┐
                                    │   RDS PostgreSQL 15    │
                                    │  davidshaevel-dev-db   │
                                    │  Status: Connected ✅  │
                                    └─────────────────────────┘
```

---

## Files Changed

### Infrastructure (Terraform)
- `terraform/modules/compute/ecr.tf` ⭐ **NEW** - ECR repository definitions
- `terraform/modules/compute/outputs.tf` - Added ECR outputs
- `terraform/modules/compute/main.tf` - Fixed health check paths, set NODE_ENV=production
- `terraform/modules/compute/variables.tf` - Updated health check path default
- `terraform/environments/dev/outputs.tf` - Added ECR outputs
- `terraform/environments/dev/variables.tf` - Set backend image to ECR URI

### Backend Application
- `backend/src/app.module.ts` - Added SSL configuration for RDS
- `backend/Dockerfile` - Installed curl for health checks

### Documentation
- `docs/2025-10-29_tt23_backend_deployment_success.md` ⭐ **NEW**
- `docs/2025-10-29_health_check_resolution.md` ⭐ **NEW**
- `docs/2025-10-29_deployment_strategy_analysis.md` - Updated deployment strategy

---

## Testing

### Manual Testing Performed
- ✅ Health endpoint returns 200 OK with database status
- ✅ Metrics endpoint returns Prometheus metrics
- ✅ ECS tasks remain stable (no restart loops)
- ✅ All health checks passing (container + target group)
- ✅ SSL connection to RDS verified in CloudWatch logs
- ✅ Backend accessible via https://davidshaevel.com/api/*

### Automated Tests
- ✅ Terraform validate passed
- ✅ Docker build succeeded
- ✅ Image scanning enabled in ECR (no critical vulnerabilities)

---

## Deployment Process

1. **Create ECR Repositories (Terraform)**
   - Applied Terraform to create backend/frontend ECR repos
   - Configured image scanning, encryption, lifecycle policies

2. **Build and Push Backend Image**
   - Built multi-stage Docker image locally
   - Tagged with `latest` and git SHA
   - Pushed to ECR: `108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend`

3. **Update ECS Task Definition**
   - Changed backend image from `nginx:latest` to ECR URI
   - Set `NODE_ENV=production` for SSL enablement
   - Fixed health check paths

4. **Deploy to ECS**
   - Terraform apply created new task definition
   - ECS performed rolling deployment
   - Old tasks drained, new tasks started

5. **Resolve Health Check Issues**
   - Updated target group health check via AWS CLI
   - Rebuilt image with curl installed
   - Force new deployment with fixed image

6. **Verify Stability**
   - Monitored CloudWatch logs for startup
   - Verified task health status
   - Tested API endpoints end-to-end

---

## Known Limitations

### Database Schema Pending
The `projects` API endpoints return 500 errors because the database table doesn't exist yet:
```bash
$ curl -s https://davidshaevel.com/api/projects
{
  "statusCode": 500,
  "message": "Internal server error"
}
```

**Why:** Backend has `synchronize: false` in production mode (safety), so tables aren't auto-created.

**Next Steps:** Create database migration or manually create schema (tracked separately).

---

## Commits (8 total)

1. **0799d00** - `feat(terraform): add ECR repositories for frontend and backend containers`
2. **f137216** - `feat(terraform): deploy backend API with ECR image`
3. **7a95e88** - `fix(backend): enable SSL for RDS database connection in production`
4. **b9a00da** - `fix(terraform): set NODE_ENV to production for backend deployment`
5. **e78ab44** - `docs: add TT-23 backend deployment success summary`
6. **b25f50c** - `fix(terraform): correct health check paths for backend API`
7. **23f5978** - `fix(backend): install curl for ECS health checks`
8. **8590cee** - `docs: document health check resolution for ECS deployment`

---

## Key Learnings

1. **RDS Always Requires SSL:** AWS RDS PostgreSQL mandates SSL/TLS connections. Always configure database clients with SSL support.

2. **Health Check Paths Must Match Routes:** When using global API prefixes, health check configurations must match exactly (e.g., `/api/health` not `/health`).

3. **Alpine Images Are Minimal:** Base Alpine images don't include utilities like `curl`. Add required tools explicitly.

4. **Multiple Health Check Layers:** ECS uses both container health checks and ALB target group health checks. Both must pass.

5. **NODE_ENV Impacts Behavior:** Environment variable configuration directly affects SSL, logging, and database sync. Ensure consistency.

---

## Success Metrics

- ✅ ECR repositories created and managed by Terraform
- ✅ Backend Docker image built and deployed (218MB optimized)
- ✅ ECS service running 2/2 desired tasks
- ✅ All health checks passing (100% healthy targets)
- ✅ Database connected with SSL encryption
- ✅ API accessible via production domain
- ✅ Zero downtime after health check fixes
- ✅ Service stable with no restart loops

---

## Related Issues

- **Linear:** [TT-23](https://linear.app/davidshaevel-dot-com/issue/TT-23) - Deploy backend to ECS Fargate
- **Follow-up:** TT-20 - Local development environment
- **Follow-up:** Database schema creation for projects table

---

## Deployment Environment

- **AWS Account:** 108581769167
- **Region:** us-east-1
- **ECS Cluster:** dev-davidshaevel-cluster
- **Backend Service:** dev-davidshaevel-backend
- **Task Definition:** dev-davidshaevel-backend:4
- **Image Tag:** 23f5978
- **Domain:** https://davidshaevel.com

---

**Deployed:** October 29, 2025  
**Backend Version:** 1.0.0  
**Status:** ✅ Production - Healthy

