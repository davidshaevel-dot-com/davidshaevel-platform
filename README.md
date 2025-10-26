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

**Frontend:** Next.js with TypeScript (planned - TT-18)  
**Backend:** Nest.js API with TypeScript and PostgreSQL (planned - TT-19)  
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

**Current State:**
- **Total Resources:** 76 AWS resources deployed
- **Monthly Cost:** ~$117-124
- **Infrastructure:** 100% complete
- **Applications:** Nginx placeholder images (TT-18, TT-19 pending)
- **Status:** https://davidshaevel.com operational (502 expected until apps deployed)

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
│   │   └── cdn/             # CloudFront, ACM (v1.0)
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
│   └── backend-setup-log.md
├── frontend/               # Next.js application (TT-18 - to be created)
├── backend/                # Nest.js API (TT-19 - to be created)
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
- **Status:** 502 expected until real applications deployed (TT-18, TT-19, TT-23)

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
- **ACM Certificate:** $0 (free)

**Total:** ~$117-124/month

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

## 🛠️ Technology Stack

**Infrastructure:**
- AWS (VPC, ECS Fargate, RDS, ALB, CloudFront, ACM)
- Terraform >= 1.13.4 (Infrastructure as Code)
- Cloudflare (DNS management)

**Application (To Be Built):**
- Next.js (Frontend) - TT-18
- Nest.js (Backend API) - TT-19
- PostgreSQL 15.12 (Database) - Deployed
- TypeScript (Language)
- Docker (Containerization)

**CI/CD (Future):**
- GitHub Actions
- Amazon ECR (Container Registry) - TT-23

## 🎯 Next Steps

### Phase: Application Development

**TT-18: Build Next.js Frontend** (8-12 hours)
- Next.js 14+ with TypeScript
- Health check endpoint at `/`
- Basic portfolio pages
- Tailwind CSS for styling
- Dockerfile for containerization

**TT-19: Build Nest.js Backend API** (10-14 hours)
- Nest.js with TypeScript
- Health check endpoint at `/api/health`
- Database integration with TypeORM
- CRUD API endpoints
- Dockerfile for containerization

**TT-23: Container Registry & Deployment** (6-8 hours)
- Create ECR repositories
- Build and push container images
- Update ECS task definitions with real images
- Replace nginx placeholders
- Verify health checks passing

**Expected Outcome:** https://davidshaevel.com serving real application

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

**Project Timeline:** October 23-26, 2025 (Infrastructure Phase Complete)  
**Status:** Infrastructure 100% Complete - Application Development Phase  
**Last Updated:** October 26, 2025

## 🤖 AI Agent Sessions

This project is developed with AI assistance (Claude Code). Session context is preserved in `.claude/AGENT_HANDOFF.md` (local only, not committed to git).

**Completed Sessions:**
- Session 1: TT-22 (Steps 8-9) - Compute Module
- Session 2: TT-24 (Step 10) - CDN Module

**Infrastructure Milestones:**
- ✅ TT-16 (Steps 1-3): Foundation
- ✅ TT-17 (Steps 4-6): Networking
- ✅ TT-21 (Step 7): Database
- ✅ TT-22 (Steps 8-9): Compute
- ✅ TT-24 (Step 10): CDN

**Next Phase:** Application Development (TT-18, TT-19, TT-23)
