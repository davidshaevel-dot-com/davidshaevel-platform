# DavidShaevel.com Platform Engineering Portfolio

A full-stack web platform showcasing DevOps best practices, infrastructure automation, and platform engineering expertise.

## 🎯 Project Purpose

This project serves as both a personal website and a demonstration of production-ready DevOps practices, including:

- **Infrastructure as Code** with Terraform
- **Cloud-Native Architecture** on AWS
- **Production-Ready Security** and best practices
- **Modular Terraform Design** with reusable components
- **Manual DNS Management** with Cloudflare

## 🏗️ Architecture

**Frontend:** Next.js 16 with TypeScript, React 19, Tailwind CSS 4 (TT-18 - Complete)  
**Backend:** Nest.js API with TypeScript, TypeORM, and PostgreSQL (TT-19 - Complete)  
**Infrastructure:** AWS (ECS Fargate, RDS PostgreSQL, VPC, CloudFront, ALB)  
**IaC:** Terraform >= 1.13.4 with modular design  
**Database:** PostgreSQL 15.12 on RDS  
**CDN:** CloudFront with custom domain  
**DNS:** Managed in Cloudflare  
**Domain:** davidshaevel.com, www.davidshaevel.com

## 📊 Infrastructure Status

### Deployed Infrastructure (100% Complete)

**Phase 1: Networking**
- ✅ VPC (10.0.0.0/16) with DNS support
- ✅ 6 Subnets across 2 AZs (public, private-app, private-db)
- ✅ 2 NAT Gateways for high availability
- ✅ Internet Gateway
- ✅ Route Tables and VPC Flow Logs
- ✅ 4 Security Groups (ALB, Frontend, Backend, Database)
- ✅ 13 Security Group Rules (least-privilege access)

**Phase 2: Database**
- ✅ RDS PostgreSQL 15.12 (db.t3.micro)
- ✅ 20GB GP3 storage with autoscaling to 100GB
- ✅ RDS-managed password in AWS Secrets Manager
- ✅ Enhanced Monitoring and Performance Insights
- ✅ 4 CloudWatch Alarms (CPU, connections, storage, memory)
- ✅ Automated backups (7-day retention)
- ✅ Encryption at rest

**Phase 3: Compute**
- ✅ ECS Fargate cluster with Container Insights
- ✅ Application Load Balancer (internet-facing, 2 AZs)
- ✅ Frontend target group (port 3000) with health checks
- ✅ Backend target group (port 3001) with health checks
- ✅ HTTP listener with path-based routing (/api/* → backend, / → frontend)
- ✅ ECS task definitions (frontend, backend)
- ✅ ECS services with desired count of 2 (high availability)
- ✅ IAM roles (task execution, frontend task, backend task)
- ✅ CloudWatch log groups (7-day retention in dev)

**Phase 4: CDN**
- ✅ CloudFront distribution with ALB origin
- ✅ ACM certificate for davidshaevel.com and *.davidshaevel.com
- ✅ Custom domain aliases configured
- ✅ HTTPS enabled with HTTP→HTTPS redirect
- ✅ Intelligent cache behaviors (static frontend vs dynamic API)
- ✅ IPv6 and HTTP/2 enabled
- ✅ Cloudflare DNS configured (gray cloud mode)

**Current State (November 2, 2025):**
- **Total Resources:** 78 AWS resources deployed (76 + 2 ECR repos)
- **Monthly Cost:** ~$117-124
- **Infrastructure:** 100% complete ✅
- **Applications:** 100% complete ✅
- **Production Deployment:** ✅ COMPLETE (October 31, 2025)
- **Testing:** Automated integration tests (14/14 passing) ✅
- **Platform Live:** https://davidshaevel.com (all 7 endpoints operational)
  - Frontend: Homepage, About, Projects, Contact pages (200 OK)
  - Backend API: https://davidshaevel.com/api/health (200 OK, DB connected)
  - Database: RDS PostgreSQL with migration system operational

## 📁 Repository Structure

```
davidshaevel-platform/
├── .claude/
│   └── AGENT_HANDOFF.md     # AI agent context (local only, not committed)
├── .github/
│   └── workflows/           # GitHub Actions CI/CD (future)
├── terraform/
│   ├── modules/
│   │   ├── networking/      # VPC, subnets, security groups (v2.1)
│   │   ├── database/        # RDS PostgreSQL (v1.1)
│   │   ├── compute/         # ECS Fargate, ALB (v1.0)
│   │   ├── cdn/             # CloudFront, ACM (v1.0)
│   │   └── observability/   # Prometheus/Grafana infrastructure (v1.0 - NEW)
│   ├── environments/
│   │   ├── dev/            # Development environment (deployed)
│   │   └── prod/           # Production environment (future)
│   ├── scripts/            # Helper scripts (validate, cost-estimate)
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md           # Terraform documentation
├── docs/
│   ├── architecture/       # AWS architecture diagrams and decisions
│   ├── terraform-local-setup.md
│   ├── terraform-implementation-plan.md  # 10-step plan (complete)
│   ├── tt-24-implementation-plan-cloudflare.md
│   ├── backend-setup-log.md
│   └── 2025-10-*_*.md     # Session agendas, summaries, PR descriptions
├── frontend/               # Next.js 16 application (TT-18 - Complete)
│   ├── app/               # Next.js App Router pages
│   ├── components/        # React components
│   ├── Dockerfile         # Multi-stage production build
│   └── README.md          # Frontend documentation (247 lines)
├── backend/                # Nest.js API (TT-19 - Complete)
│   ├── src/               # Application source code
│   ├── scripts/           # Testing scripts
│   ├── Dockerfile         # Multi-stage production build
│   └── README.md          # Backend documentation (627 lines)
├── .envrc                  # Environment variables (local only, not committed)
├── .envrc.example          # Environment template
└── README.md
```

## 🚀 Getting Started

### Prerequisites

- **AWS Account:** Configured with appropriate permissions
- **AWS CLI:** Installed and configured with SSO
- **Terraform:** >= 1.13.4
- **direnv:** For automatic environment variable loading (optional)
- **GitHub CLI (gh):** For PR management (optional)

### Environment Setup

1. **Configure AWS SSO:**
```bash
aws sso login --profile davidshaevel-dev
```

2. **Set up environment variables:**
```bash
cp .envrc.example .envrc
# Edit .envrc with your actual values
source .envrc
```

3. **Initialize Terraform:**
```bash
cd terraform/environments/dev
terraform init
```

### Infrastructure Deployment

The infrastructure follows a 10-step implementation plan (all complete):

**Steps 1-3: Foundation** (TT-16 - Complete)
- Terraform configuration and backend
- Environment structure
- Helper scripts

**Steps 4-6: Networking** (TT-17 - Complete)
- VPC and Internet Gateway
- Subnets, NAT Gateways, routing
- Security groups

**Step 7: Database** (TT-21 - Complete)
- RDS PostgreSQL with Secrets Manager

**Steps 8-9: Compute** (TT-22 - Complete)
- ECS Fargate cluster and ALB
- Task definitions and services

**Step 10: CDN** (TT-24 - Complete)
- CloudFront distribution
- ACM certificate
- Cloudflare DNS integration

### Verify Infrastructure

```bash
cd terraform/environments/dev
terraform plan  # Should show "No changes"
terraform output  # View all outputs
```

### Access Points

- **Primary Domain:** https://davidshaevel.com
- **Alternate Domain:** https://www.davidshaevel.com
- **CloudFront Distribution:** `EJVDEMX0X00IG`
- **ECS Cluster:** `dev-davidshaevel-cluster`
- **Applications:** Frontend and Backend built, ready for deployment (TT-23)
- **Testing:** 14 automated integration tests passing

## 🔧 Terraform Modules

### Networking Module (v2.1)
- VPC with configurable CIDR
- Multi-AZ subnet configuration (public, private-app, private-db)
- NAT Gateways with Elastic IPs
- Internet Gateway
- Route tables and associations
- VPC Flow Logs with CloudWatch
- Security groups with least-privilege rules

### Database Module (v1.1)
- RDS PostgreSQL with configurable instance class
- RDS-managed password with Secrets Manager
- DB subnet group in private subnets
- Enhanced monitoring and Performance Insights
- Dynamic CloudWatch alarms (scale with instance size)
- Automated backups with configurable retention
- Encryption at rest

### Compute Module (v1.0)
- ECS Fargate cluster with Container Insights
- Application Load Balancer (ALB)
- Target groups with health checks
- ECS task definitions (frontend, backend)
- ECS services with auto-scaling support
- IAM roles with least-privilege access
- CloudWatch log groups
- Optional HTTPS listener support
- Database integration via Secrets Manager

### CDN Module (v1.0)
- CloudFront distribution with ALB origin
- ACM certificate with DNS validation
- Custom domain support
- Intelligent cache behaviors (static vs dynamic)
- HTTP→HTTPS redirect
- IPv6 and HTTP/2 support
- Custom error responses
- Manual Cloudflare DNS workflow (documented)

## 🔒 Security

- **IAM:** Least privilege access with separate task execution and task roles
- **Secrets:** AWS Secrets Manager for database credentials
- **Encryption:** Data encrypted at rest (RDS, CloudWatch Logs)
- **SSL/TLS:** HTTPS enforced with HTTP→HTTPS redirect (TLS 1.2+)
- **Network:** VPC with proper subnet segmentation and security groups
- **Database:** Private subnets only, no public access, zero egress rules
- **Compliance:** Following AWS Well-Architected Framework principles

## 💰 Cost Breakdown (Monthly)

- **NAT Gateways:** ~$68.50 (2 for high availability)
- **ALB:** ~$16-20
- **RDS PostgreSQL (db.t3.micro):** ~$16
- **ECS Fargate (4 tasks, 0.25 vCPU, 0.5 GB each):** ~$14
- **CloudFront:** ~$2-4 (low traffic, free tier)
- **CloudWatch Logs:** ~$1
- **VPC Flow Logs:** Minimal
- **Observability (EFS + S3):** ~$1.10 (new - TT-25 Phase 3)
- **ACM Certificate:** $0 (free)

**Total:** ~$118-125/month

## 📝 Documentation

### Key Documents
- [Terraform Local Setup](docs/terraform-local-setup.md) - Environment configuration
- [Implementation Plan](docs/terraform-implementation-plan.md) - 10-step plan (complete)
- [TT-24 Implementation](docs/tt-24-implementation-plan-cloudflare.md) - CDN with Cloudflare
- [Backend Setup](docs/backend-setup-log.md) - S3 + DynamoDB state backend
- [Architecture Docs](docs/architecture/) - AWS architecture diagrams

### Module Documentation
- [Networking Module](terraform/modules/networking/README.md) - 276 lines
- [Database Module](terraform/modules/database/README.md) - 276 lines
- [Compute Module](terraform/modules/compute/README.md) - 533 lines
- [CDN Module](terraform/modules/cdn/README.md) - 555 lines
- [Observability Module](terraform/modules/observability/README.md) - 340 lines (new - TT-25 Phase 3)
- Service Discovery Module - 350+ lines (new - TT-25 Phase 4, README pending)

## 🛠️ Technology Stack

**Infrastructure:**
- AWS (VPC, ECS Fargate, RDS, ALB, CloudFront, ACM)
- Terraform >= 1.13.4 (Infrastructure as Code)
- Cloudflare (DNS management)

**Application (Built):**
- Next.js 16 (Frontend) - TT-18 ✅
- Nest.js (Backend API) - TT-19 ✅
- PostgreSQL 15.12 (Database) - Deployed ✅
- TypeScript 5 (Language)
- Docker (Containerization) - Multi-stage builds ✅
- Automated Testing (14 integration tests) - TT-28 ✅

**CI/CD:**
- GitHub Actions (automated workflows)
- Amazon ECR (Container Registry)

## 🎯 Application Status

### Completed Applications

**✅ TT-18: Next.js Frontend** (Complete)
- Next.js 16 with TypeScript, React 19
- Health check endpoint (`/api/health`)
- Metrics endpoint (`/api/metrics`)
- 4 pages (Home, About, Projects, Contact)
- Tailwind CSS 4 for styling
- Multi-stage Dockerfile (604MB optimized)
- 26 files, 8,126+ lines

**✅ TT-19: Nest.js Backend API** (Complete)
- Nest.js with TypeScript, TypeORM
- Health check endpoint with DB status
- Metrics endpoint (Prometheus format)
- Projects CRUD API
- Request validation with DTOs
- Multi-stage Dockerfile (optimized)
- 26 files, 2,847+ lines

**✅ TT-28: Automated Integration Testing** (Complete)
- 14 comprehensive integration tests
- Docker orchestration (PostgreSQL + Backend)
- 100% test pass rate
- CI/CD ready with multiple modes
- 553-line bash test script

**✅ TT-23: Backend Deployed to ECS** (Complete - Oct 29, 2025)
- ECR repository created (immutable tags)
- Backend image: `davidshaevel/backend:1431417-schema-sync`
- Deployed via Terraform with explicit git SHA tags
- 2/2 ECS tasks healthy, ALB targets healthy
- Database connected with SSL (relaxed validation)
- Migration system operational (idempotent, atomic)
- Production API live: https://davidshaevel.com/api/health

**✅ TT-29: Frontend Deployed to ECS** (Complete - Oct 30-31, 2025)
- ECR repository created (immutable tags)
- Frontend image: `davidshaevel/frontend:2d9f19a-health-fix`
- 2/2 ECS tasks healthy, ALB targets healthy
- CloudFront serving correctly with SSL
- Three critical fixes implemented:
  - Health endpoint routing conflict resolved
  - ECS task health check configuration fixed
  - CloudFront homepage 404 error resolved
- All pages operational: Home, About, Projects, Contact

### Production Status

**✅ Full-Stack Platform Deployed** (October 31, 2025)

**All Endpoints Operational (200 OK):**
- ✅ https://davidshaevel.com/ - Homepage
- ✅ https://davidshaevel.com/about - About page
- ✅ https://davidshaevel.com/projects - Projects page
- ✅ https://davidshaevel.com/contact - Contact page
- ✅ https://davidshaevel.com/health - Frontend health check
- ✅ https://davidshaevel.com/api/health - Backend health check
- ✅ https://davidshaevel.com/api/projects - Backend API

**Infrastructure Health:**
- ✅ 2 frontend ECS tasks: HEALTHY
- ✅ 2 backend ECS tasks: HEALTHY
- ✅ ALB targets: All healthy
- ✅ RDS database: Connected and operational
- ✅ CloudFront CDN: Serving correctly

**Deployment Process:** Automated via GitHub Actions (TT-31 Complete)

### Completed Enhancements

**✅ TT-31: GitHub Actions CI/CD Workflows** (Complete - November 6, 2025)
- Automated testing on every push (lint + tests)
- Automated Docker builds and ECR push
- Automated ECS deployments triggered by path changes
- Eliminated manual deployment steps
- Portfolio enhancement: Demonstrates CI/CD expertise
- 6 PRs merged, both workflows fully operational

### Planned Enhancements

**TT-20: Local Development Environment** (6-8 hours) - Priority 1
- Docker Compose for full-stack local development
- PostgreSQL + Frontend + Backend containers
- Hot reload for rapid iteration
- Frontend-backend integration testing

**TT-25: Observability with Grafana/Prometheus** (8-10 hours) - Priority 3 [IN PROGRESS]
- ✅ Phase 1: Docker configurations (PR #32 - Complete Nov 7)
- ✅ Phase 2: Prometheus templating system (PR #33 - Complete Nov 9)
- ✅ Phase 3: EFS file systems and observability module (PR #37, #38, #39 - Complete Nov 11-12)
  - New Terraform module: `terraform/modules/observability/` (840 lines)
  - EFS for Prometheus TSDB data persistence with encryption
  - S3 bucket for config storage with versioning
  - Multi-AZ deployment, security groups, IAM policies
  - EFS lifecycle fix (AWS API compliance)
  - 16 AWS resources, ~$1.10/month cost
- ✅ Phase 4: AWS Cloud Map service discovery (PR #41 - Complete Nov 12)
  - New Terraform module: `terraform/modules/service-discovery/` (350+ lines)
  - Private DNS namespace (davidshaevel.local) for internal service resolution
  - Service discovery for backend and frontend with A and SRV records
  - for_each patterns, dynamic blocks, and consolidated outputs for maintainability
- ✅ Phase 5: Prometheus ECS deployment (PR #44, #45 - Complete Nov 13)
  - Prometheus ECS service deployed with EFS persistence
  - ECS Exec enabled for debugging and endpoint testing
  - "Recreate" deployment strategy implemented to solve EFS locking
  - Deployment circuit breaker with automatic rollback
  - Comprehensive test script (6 tests validating service health)
  - All core functionality operational: health checks, metrics, targets
  - ~90 second deployment time, no manual intervention required
- ✅ Phase 6: Test script fixes and ECS Exec expansion (PR #46, #47 - Complete Nov 14)
  - Fixed 4 critical issues in test-prometheus-deployment.sh script (TT-52)
  - ECS Exec enabled for backend and frontend containers
  - Refactored IAM policy attachments using for_each pattern (DRY principle)
  - All 6 tests passing with ECS Exec validation working
  - Gemini code review feedback implemented (31% code reduction)
- ⏳ Phase 7-8: Enhanced metrics endpoints (backend + frontend)
- ⏳ Phase 9-10: Dashboards, deployment, and verification

**TT-26: Documentation & Demo Materials** (4-6 hours) - Priority 4
- Architecture diagrams
- Deployment runbook
- Interview talking points
- Portfolio demonstration materials

## 🚀 Deployment

### Current Deployment Process (Manual)

**Backend Deployment:**
```bash
# 1. Build Docker image locally
cd backend
docker build -t backend:$(git rev-parse --short HEAD) .

# 2. Tag for ECR
docker tag backend:$(git rev-parse --short HEAD) \
  108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:$(git rev-parse --short HEAD)

# 3. Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  108581769167.dkr.ecr.us-east-1.amazonaws.com

# 4. Push to ECR
docker push 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:$(git rev-parse --short HEAD)

# 5. Update Terraform with new image tag
cd terraform/environments/dev
# Edit main.tf or variables.tf with new image tag

# 6. Deploy via Terraform
terraform plan
terraform apply

# 7. Verify deployment
aws ecs list-tasks --cluster dev-davidshaevel-cluster
aws ecs describe-tasks --cluster dev-davidshaevel-cluster --tasks <task-arn>
curl https://davidshaevel.com/api/health
```

**Frontend Deployment:**
```bash
# Build and push frontend image (same as backend)
cd frontend
docker build -t frontend:$(git rev-parse --short HEAD) .
docker tag frontend:$(git rev-parse --short HEAD) \
  108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend:$(git rev-parse --short HEAD)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  108581769167.dkr.ecr.us-east-1.amazonaws.com
docker push 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend:$(git rev-parse --short HEAD)

# Update Terraform and deploy
cd terraform/environments/dev
# Set the frontend_container_image variable with full ECR image URI
terraform apply -var 'frontend_container_image=108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend:<git-sha>'

# CRITICAL: Invalidate CloudFront cache for changes to be visible
aws cloudfront create-invalidation --distribution-id <distribution-id> --paths "/*"
```

**Database Migrations:**
```bash
# NOTE: Current backend Dockerfile does not include database/ directory in production image.
# Migrations must be run from local machine with database access, OR Dockerfile must be updated.

# Option 1: Run from local machine (recommended for now)
cd backend
node database/run-migration.js \
  --host <rds-endpoint> \
  --port 5432 \
  --database <dbname> \
  --username <username> \
  --password <password> \
  <migration-file.sql>

# Option 2: Update Dockerfile to include database directory (future enhancement)
# Add to backend/Dockerfile runner stage: COPY --from=builder /app/database ./database
```

### Automated CI/CD Process

**✅ Status:** Fully operational (TT-31 Complete - November 6, 2025)

Deployments are now fully automated via GitHub Actions:

#### Developer Workflow

1. **Make changes:**
   - Edit code in `backend/` or `frontend/`
   - Commit to main branch (or feature branch for PRs)

2. **Automatic deployment:**
   - Push triggers CI/CD workflow automatically
   - Path-based triggers: `backend/**` or `frontend/**`
   - Concurrent deployment prevention ensures safe deployments

#### CI/CD Pipeline

**Backend Workflow** (`.github/workflows/backend-deploy.yml`):
1. **Test & Lint** (~20s)
   - ESLint code quality checks
   - Jest unit tests
2. **Build & Push** (~35-40s)
   - Docker multi-stage build
   - Tag with git short SHA (e.g., `6881409`)
   - Push to ECR with immutable tags
3. **Deploy to ECS** (~3 minutes)
   - Download current task definition
   - Update with new image
   - Deploy to ECS Fargate
   - Wait for service stability (health checks)
   - Retrieve service URL from ALB

**Frontend Workflow** (`.github/workflows/frontend-deploy.yml`):
1. **Test & Lint** (~28s)
   - ESLint code quality checks
   - Next.js build validation (TypeScript type checking)
2. **Build & Push** (~55-60s)
   - Docker multi-stage build
   - Tag with git short SHA
   - Push to ECR with immutable tags
3. **Deploy to ECS** (~3 minutes)
   - Download current task definition
   - Update with new image
   - Deploy to ECS Fargate
   - Wait for service stability (health checks)
   - Retrieve service URL from ALB

**Total Deployment Time:** ~5-7 minutes from push to production

#### Workflow Features

**Automatic Triggers:**
- ✅ Push to `main` with backend changes → Backend workflow
- ✅ Push to `main` with frontend changes → Frontend workflow
- ✅ Path-based filtering prevents unnecessary deployments

**Manual Triggers:**
- ✅ `workflow_dispatch` for on-demand deployments
- ✅ Environment selection (dev/prod)

**Concurrency Control:**
- ✅ One deployment per environment at a time
- ✅ Queued deployments wait for current deployment to complete
- ✅ `cancel-in-progress: false` ensures safe sequential deployments

**Security:**
- ✅ GitHub environment secrets (dev/prod isolation)
- ✅ AWS IAM least-privilege credentials
- ✅ ECR immutable tags prevent image overwrites

**Observability:**
- ✅ Deployment summary with service URLs
- ✅ CloudWatch Logs integration (7-day retention)
- ✅ GitHub Actions run history

#### Rollback

If a deployment fails or causes issues:

**Option 1: Revert and Redeploy**
```bash
git revert <bad-commit-sha>
git push origin main
# CI/CD automatically deploys previous version
```

**Option 2: Manual Rollback (Immediate)**
```bash
# Find previous task definition revision
aws ecs list-task-definitions --family-prefix dev-davidshaevel-backend --sort DESC

# Update service to previous task definition (backend example)
aws ecs update-service \
  --cluster dev-davidshaevel-cluster \
  --service dev-davidshaevel-backend \
  --task-definition dev-davidshaevel-backend:<revision>

# For frontend, replace 'backend' with 'frontend' in the commands above
```

#### GitHub Secrets Configuration

Each environment (dev/prod) requires these secrets:

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID          # IAM user access key
AWS_SECRET_ACCESS_KEY      # IAM user secret key
AWS_REGION                 # us-east-1

# ECR Repositories (full URIs)
ECR_BACKEND_REPOSITORY     # 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend
ECR_FRONTEND_REPOSITORY    # 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend

# ECS Configuration
ECS_CLUSTER                # dev-davidshaevel-cluster
ECS_BACKEND_SERVICE        # dev-davidshaevel-backend
ECS_FRONTEND_SERVICE       # dev-davidshaevel-frontend
```

See [docs/prod-environment-setup.md](docs/prod-environment-setup.md) for production setup instructions.

#### Monitoring Deployments

**Watch workflow runs:**
```bash
# List recent runs
gh run list --workflow=backend-deploy.yml --limit 5
gh run list --workflow=frontend-deploy.yml --limit 5

# Watch current run
gh run watch <run-id>

# View run details
gh run view <run-id>
```

**Check ECS deployment status:**
```bash
# List running tasks
aws ecs list-tasks --cluster dev-davidshaevel-cluster

# Check service status
aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend dev-davidshaevel-frontend
```

**Tail CloudWatch logs:**
```bash
# Backend logs
aws logs tail /ecs/dev-davidshaevel/backend --since 10m --follow

# Frontend logs
aws logs tail /ecs/dev-davidshaevel/frontend --since 10m --follow
```

## 🔄 Git Workflow

**Branch Naming:**
- Feature branches: `claude/<issue-id>-<description>`
- Example: `claude/tt-18-nextjs-frontend`

**Commit Format:**
- Conventional Commits: `<type>(<scope>): <description>`
- Types: `feat`, `fix`, `docs`, `chore`, `refactor`
- Always include: `related-issues: <ID>`

**PR Process:**
- Comprehensive PR descriptions
- Code review with Gemini Code Assist
- Testing and validation
- Merge to main and delete branch

## 📞 Contact

**David Shaevel**  
Platform Engineer | DevOps Specialist  
Austin, Texas

---

**Project Timeline:**
- Infrastructure: October 23-26, 2025 (100% Complete)
- Applications: October 28-29, 2025 (100% Complete)
- Backend Deployment: October 29, 2025 (Complete)
- Database & Migration System: October 30, 2025 (Complete)
- Frontend Deployment: October 30-31, 2025 (Complete)
- PR Feedback & Security Fixes: October 31, 2025 (Complete)

**Status:** ✅ PRODUCTION DEPLOYMENT COMPLETE
**Last Updated:** November 12, 2025

## 🤖 AI Agent Sessions

This project is developed with AI assistance (Claude Code). Session context is preserved in `.claude/AGENT_HANDOFF.md` (local only, not committed to git).

**Completed Sessions:**
- Oct 26 Session 1: TT-22 (Steps 8-9) - Compute Module
- Oct 26 Session 2: TT-24 (Step 10) - CDN Module
- Oct 28: TT-18 - Next.js Frontend Application
- Oct 29 AM: TT-19 - Nest.js Backend API
- Oct 29 AM: TT-28 - Automated Integration Testing
- Oct 29 PM: TT-23 - Backend Deployment to ECS (PR #18, #19)
- Oct 30: Database schema & initial frontend deployment (PR #20, #21)
- Oct 31: Frontend fixes & PR feedback (PR #22)
- Nov 2: CI/CD issue creation & documentation updates (TT-31)
- Nov 5: TT-31 Phase 1 - GitHub IAM setup (PR #25)
- Nov 5: TT-31 Phase 2 - Backend CI/CD workflow (PR #26, #27, #28)
- Nov 6: TT-31 Phase 3 - Frontend CI/CD workflow (PR #29, #30)
- Nov 6: TT-31 Phase 4 & 5 - Testing, validation, and documentation

**Infrastructure Milestones:**
- ✅ TT-16 (Steps 1-3): Foundation
- ✅ TT-17 (Steps 4-6): Networking
- ✅ TT-21 (Step 7): Database
- ✅ TT-22 (Steps 8-9): Compute
- ✅ TT-24 (Step 10): CDN

**Application Milestones:**
- ✅ TT-18: Next.js Frontend (Complete)
- ✅ TT-19: Nest.js Backend (Complete)
- ✅ TT-28: Automated Testing (Complete)
- ✅ TT-23: Backend Deployment (Complete - Oct 29, 2025)
- ✅ TT-29: Frontend Deployment (Complete - Oct 30-31, 2025)
- ✅ TT-31: CI/CD Workflows (Complete - Nov 6, 2025)
- ⏳ TT-25: Observability (In Progress - Phase 3/10 Complete - Nov 11, 2025)
- ⏳ TT-20: Local Development (Planned - 6-8 hours)
- ⏳ TT-26: Documentation (Planned - 4-6 hours)

**Current Phase:** Production operational with automated CI/CD, actively building observability infrastructure (Prometheus/Grafana)
