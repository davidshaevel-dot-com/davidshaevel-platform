# DavidShaevel.com Platform - Claude Context

<!-- If CLAUDE.local.md exists, read it for additional context (AWS resource IDs, environment details, etc.) -->

## Project Overview

This is a full-stack engineering portfolio platform demonstrating AWS cloud architecture, infrastructure as code, and modern web development practices. The project uses Terraform for infrastructure management and follows a disciplined, incremental approach.

**Key Technologies:**
- **Infrastructure:** Terraform, AWS (VPC, ECS Fargate, RDS, CloudFront, Route53)
- **Frontend:** Next.js, TypeScript, React
- **Backend:** Node.js/Nest.js API
- **IaC:** Terraform >= 1.13.4, AWS Provider ~> 6.18.0
- **Observability:** Prometheus, Grafana, CloudWatch

**Project Management:**
- **Issue Tracking:** Linear (Team Tacocat)
- **Version Control:** GitHub
- **Branching Strategy:** Feature branches with PR workflow

---

## Architecture

```
Internet
    │
    ▼
CloudFront (CDN)
    │
    ▼
Application Load Balancer (Public Subnets)
    │
    ├── Frontend Target Group (port 3000)
    │       │
    │       ▼
    │   Frontend ECS Service (Private App Subnets)
    │       │
    │       ▼
    │   Frontend Tasks (2x for HA)
    │
    ├── Backend Target Group (port 3001)
            │
            ▼
        Backend ECS Service (Private App Subnets)
            │
            ▼
        Backend Tasks (2x for HA)
            │
            ▼
        RDS PostgreSQL (Private DB Subnets)
```

**Infrastructure Highlights:**
- VPC with 6 subnets across 2 AZs (public, private-app, private-db)
- NAT Gateways for HA outbound traffic
- Security groups with least-privilege access
- ECS Fargate for serverless container management
- RDS PostgreSQL with encryption and automated backups
- CloudFront CDN with custom domain and HTTPS

---

## Development Process & Conventions

### Git Workflow

**Branch Naming Convention:**
```
claude/<issue-id>-<brief-description>
david/<issue-id>-<brief-description>
```

Examples:
- `claude/tt-16-step-1-terraform-foundation`
- `david/tt-19-nestjs-backend`

**Commit Message Format (Conventional Commits):**

```
<type>(<scope>): <short description>

<detailed description>

<body with changes, features, testing, etc.>

related-issues: <ISSUE-ID>

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:**
- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `refactor`: Code refactoring
- `test`: Test additions/changes

### Pull Request Process

**CRITICAL: NEVER MERGE WITHOUT CODE REVIEW**

All pull requests follow this workflow:

1. **Create PR** with descriptive title and comprehensive description
2. **Add warning:** "AWAITING CODE REVIEW - DO NOT MERGE"
3. **Wait for review** (Gemini Code Assist or human reviewer)
4. **Address feedback:**
   - CRITICAL and HIGH issues: Must fix
   - MEDIUM issues: Evaluate and decide
5. **Post summary comment** with all fixes addressed
6. **Merge only after** all review feedback resolved

**Review Response Format:**
```markdown
## Security Issues Resolved

**Commit:** `<hash>` - <commit message>

### CRITICAL Issue Fixed: <description>
**Problem:** <description>
**Solution:** <fix>
**Result:** <outcome>

### Testing & Validation
- terraform fmt - passed
- terraform validate - passed
- terraform plan - <results>
```

---

## Important File Locations

### Documentation
- `docs/architecture/` - AWS architecture documentation
- `docs/terraform-local-setup.md` - Local environment setup
- `docs/terraform-implementation-plan.md` - 10-step implementation plan

### Terraform Configuration
- `terraform/` - Root Terraform configuration
- `terraform/environments/dev/` - Dev environment
- `terraform/environments/prod/` - Prod environment (template)
- `terraform/scripts/` - Helper scripts
- `terraform/modules/networking/` - VPC, subnets, security groups
- `terraform/modules/database/` - RDS PostgreSQL
- `terraform/modules/compute/` - ECS Fargate, ALB
- `terraform/modules/cdn/` - CloudFront, ACM

### Applications
- `frontend/` - Next.js frontend application
- `backend/` - Nest.js backend API

### Security
- `.envrc` - Environment variables (gitignored)
- `.envrc.example` - Template with placeholder values
- All `.tfvars` files are gitignored
- Only `.tfvars.example` files are committed

---

## Helpful Commands

```bash
# Switch to main and update
git checkout main && git pull

# Create feature branch
git checkout -b claude/tt-XX-feature-description

# Terraform workflow
cd terraform/environments/dev
source ../../../.envrc  # Load environment variables
terraform init
terraform validate
terraform plan
terraform apply

# Validation across all environments
./terraform/scripts/validate-all.sh

# Cost estimation
./terraform/scripts/cost-estimate.sh dev

# Format Terraform files
terraform fmt -recursive

# Create PR
gh pr create --title "feat(terraform): ..." --body "..."

# View PR reviews
gh pr view <number> --json reviews,comments
gh api repos/<org>/<repo>/pulls/<number>/comments

# Post comment on PR
gh pr comment <number> --body "..."

# Check infrastructure state
cd terraform/environments/dev
terraform state list
terraform show
```

---

## Key Conventions Summary

- **Always use feature branches** named `claude/<issue>-<description>` or `david/<issue>-<description>`
- **Conventional Commits** with "related-issues: X"
- **Test before committing** (validate, format, run scripts)
- **Evaluate review comments** (CRITICAL/HIGH must fix, MEDIUM evaluate)
- **Post comprehensive PR comment** summarizing all fixes
- **Update Linear with accurate status**
- **Use generic placeholders** in all example files
- **Never commit sensitive data** (use .envrc, not committed)
- **Add validations** to prevent configuration errors
- **Document decisions** (why we accepted or rejected suggestions)

---

## Application Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Frontend Next.js application |
| `/api/*` | Backend API routes (proxied through CloudFront) |
| `/api/health` | Backend health check |
| `/api/metrics` | Prometheus metrics endpoint |
| `/api/contact` | Contact form email submission (POST) |

---

## Environment Variables

The following environment variables are required (set in `.envrc`):

| Variable | Description |
|----------|-------------|
| `TF_VAR_aws_account_id` | AWS Account ID |
| `TF_VAR_project_name` | Project identifier |
| `TF_VAR_domain_name` | Primary domain name |
| `AWS_PROFILE` | AWS CLI profile name |
| `AWS_REGION` | AWS region |

See `.envrc.example` for the full template.

---

## Repository Structure

```
davidshaevel-platform/
│
├── CLAUDE.md                          # Public project context (this file)
├── CLAUDE.local.md                    # Sensitive project context (gitignored)
├── README.md                          # Main repository documentation
├── .gitignore                         # Git ignore patterns
├── .envrc.example                     # Example environment variables
│
├── observability/                     # Observability Stack (Prometheus, Grafana)
│   ├── prometheus/
│   │   ├── Dockerfile                 # Custom Prometheus image
│   │   ├── prometheus.yml             # DEV environment config (pre-rendered)
│   │   ├── prometheus.yml.tpl         # Terraform template for all environments
│   │   └── README.md                  # Prometheus documentation
│   │
│   └── grafana/
│       ├── Dockerfile                 # Custom Grafana image
│       └── README.md                  # Grafana documentation
│
├── terraform/                         # Infrastructure as Code
│   ├── versions.tf                    # Terraform version constraints
│   ├── provider.tf                    # AWS provider configuration
│   ├── backend.tf                     # S3 + DynamoDB state backend
│   ├── variables.tf                   # Root-level variables
│   ├── outputs.tf                     # Root-level outputs
│   ├── README.md                      # Terraform documentation
│   │
│   ├── modules/                       # Reusable Terraform modules
│   │   ├── networking/                # VPC, subnets, NAT, security groups
│   │   ├── database/                  # RDS PostgreSQL
│   │   ├── compute/                   # ECS Fargate, ALB, target groups
│   │   ├── cdn/                       # CloudFront distribution
│   │   ├── observability/             # S3, EFS for Prometheus/Grafana
│   │   ├── service-discovery/         # AWS Cloud Map
│   │   └── dr-snapshot-replication/   # Cross-region snapshot copy
│   │
│   ├── environments/
│   │   ├── dev/                       # DEV environment (us-east-1)
│   │   ├── prod/                      # PROD environment (template)
│   │   └── dr/                        # DR environment (us-west-2)
│   │
│   └── scripts/                       # Helper scripts
│       ├── setup-backend.sh           # Initialize Terraform backend
│       ├── validate-all.sh            # Validate all environments
│       ├── cost-estimate.sh           # Infracost wrapper
│       ├── dr-validation.sh           # DR readiness checks (18 checks)
│       ├── dr-failover.sh             # DR activation script
│       └── dr-failback.sh             # Return to primary script
│
├── backend/                           # Backend application (Nest.js)
│   ├── src/
│   │   ├── app.module.ts              # Main application module
│   │   ├── main.ts                    # Application entry point
│   │   ├── projects/                  # Projects API module
│   │   └── database/                  # Database configuration
│   │
│   ├── database/
│   │   └── migrations/                # SQL migration files
│   │
│   ├── Dockerfile                     # Production container image
│   └── package.json
│
├── frontend/                          # Frontend application (Next.js)
│   ├── app/
│   │   ├── layout.tsx                 # Root layout
│   │   ├── page.tsx                   # Homepage
│   │   ├── about/page.tsx             # About page
│   │   ├── projects/page.tsx          # Projects page
│   │   ├── contact/page.tsx           # Contact page
│   │   ├── health/route.ts            # Health check endpoint
│   │   └── api/metrics/route.ts       # Prometheus metrics endpoint
│   │
│   ├── components/                    # React components
│   ├── Dockerfile                     # Production container image
│   └── package.json
│
├── docs/                              # Project documentation
│   ├── terraform-local-setup.md
│   ├── terraform-implementation-plan.md
│   ├── aws-architecture.md
│   └── dr-failover-runbook.md         # DR procedures and troubleshooting
│
├── scripts/                           # Root-level operational scripts
│   ├── dr-failover.sh                 # Activate DR environment
│   ├── dr-failback.sh                 # Return to primary region
│   ├── dr-validation.sh               # Validate DR readiness (18 checks)
│   └── grafana-dns-switch.sh          # Switch Grafana DNS between dev/DR
│
└── .github/
    └── workflows/                     # GitHub Actions CI/CD
```

---

## Observability Stack

The platform includes a comprehensive observability stack:

**Prometheus:**
- Custom Docker image based on prom/prometheus:v2.48.1
- 3 scrape jobs: backend, frontend, prometheus self-monitoring
- DNS service discovery via AWS Cloud Map (SRV records)
- EFS persistence for TSDB data
- S3 for configuration delivery
- 15-second scrape interval, 15-day data retention

**Grafana:**
- Custom Docker image based on grafana/grafana:11.3.0
- Anonymous auth enabled for demo access
- Provisioned datasources and dashboards
- EFS persistence for configuration

**Service Discovery:**
- AWS Cloud Map private DNS namespace
- Both A and SRV DNS records (10-second TTL)
- Multivalue routing policy
- Health checks managed by ECS

---

## Disaster Recovery (DR) Environment

The platform implements a **Pilot Light** DR strategy in us-west-2:

**Architecture:**
- Separate VPC (10.1.0.0/16) with 6 subnets across 2 AZs
- RDS PostgreSQL restored from cross-region snapshots
- ECS Fargate cluster with 4 services
- Application Load Balancer with health checks
- KMS key for cross-region encryption

**Automated Snapshot Replication:**
- EventBridge rule triggers on RDS snapshot creation
- Lambda function copies snapshots to us-west-2 with re-encryption
- Configurable retention and frequency

**Operational Scripts:**
- `scripts/dr-validation.sh` - 18 readiness checks
- `scripts/dr-failover.sh` - Activates DR, updates CloudFront
- `scripts/dr-failback.sh` - Returns to primary region
- `scripts/grafana-dns-switch.sh` - Switch Grafana DNS between dev/DR via Cloudflare API

**Recovery Metrics:**
- **RTO:** ~15-20 minutes
- **RPO:** ~1 hour (configurable)

See `docs/dr-failover-runbook.md` for procedures and troubleshooting.

---

## Completed Linear Issues

**Infrastructure (TT-16 through TT-24):**
- TT-16: Terraform project structure
- TT-17: VPC and networking
- TT-21: Database module (RDS PostgreSQL)
- TT-22: Compute module (ECS Fargate, ALB)
- TT-24: CDN module (CloudFront, ACM)

**Applications (TT-18, TT-19, TT-28):**
- TT-18: Frontend application (Next.js)
- TT-19: Backend application (Nest.js)
- TT-28: Automated integration testing

**Observability (TT-25):**
- Phase 1-6: Docker configs, templating, EFS, Cloud Map, services

**Disaster Recovery (TT-65, TT-73, TT-75, TT-87):**
- TT-65: Pilot Light DR environment in us-west-2
- TT-73: DR deployment testing with failover/failback scripts
- TT-75: Fix ECR repos incorrectly targeted for destruction during DR activation
- TT-87: DR cutover exercise with Resend configuration and grafana-dns-switch.sh script

**Contact Form (TT-78, TT-84, TT-85):**
- TT-78: Contact form email functionality (Resend API integration)
- TT-84: Contact form frontend fix (CloudFront cache causing stale assets)
- TT-85: CloudFront IAM permissions for CI/CD cache invalidation

**Vercel Migration (TT-89, TT-90, TT-91, TT-92 complete):**
- TT-89: Neon database setup (free tier PostgreSQL 15)
- TT-90: NestJS backend adapted for Vercel serverless (native request/response handler)
- TT-91: Vercel deployment (frontend + backend deployed, custom domain configured)
- TT-92: Custom domain + DNS switch (davidshaevel.com → Vercel via Cloudflare API)

---

## References

- **Linear Project:** [DavidShaevel.com Platform](https://linear.app/davidshaevel-dot-com/project/davidshaevelcom-platform-engineering-portfolio-ebad3e1107f6)
- **Implementation Plan:** `docs/terraform-implementation-plan.md`
- **Local Setup Guide:** `docs/terraform-local-setup.md`
- **Architecture Docs:** `docs/architecture/`
- **DR Runbook:** `docs/dr-failover-runbook.md`
