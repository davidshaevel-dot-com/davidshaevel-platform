# Architecture Overview

**Project:** DavidShaevel.com Platform
**Date:** December 26, 2025
**Author:** David Shaevel
**Version:** 2.0

**Status:** ✅ Production Complete - Platform live at https://davidshaevel.com

---

## 🎯 Architecture Goals

1. **Production-Ready:** Enterprise-grade infrastructure suitable for real-world use
2. **DevOps Excellence:** Showcase infrastructure automation and CI/CD best practices
3. **Observability:** Comprehensive monitoring and alerting
4. **Security-First:** AWS best practices, least privilege, encrypted data
5. **Cost-Optimized:** Efficient resource utilization
6. **Scalable:** Design supports future growth

---

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Cloudflare DNS                          │
│    davidshaevel.com | grafana.davidshaevel.com              │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                  AWS CloudFront CDN                         │
│              (SSL/TLS Termination)                          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                 Application Load Balancer                   │
│                  (ALB - Multi-AZ)                           │
│  /api/* → Backend | /* → Frontend | /grafana/* → Grafana    │
└──────┬─────────────────┬─────────────────┬──────────────────┘
       │                 │                 │
┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐
│ ECS Fargate │   │ ECS Fargate │   │ ECS Fargate │
│  Frontend   │   │   Backend   │   │   Grafana   │
│  (Next.js)  │   │  (Nest.js)  │   │ Dashboards  │
│   :3000     │   │   :3001     │   │   :3000     │
└─────────────┘   └──────┬──────┘   └──────┬──────┘
                         │                 │
              ┌──────────▼──────┐   ┌──────▼──────┐
              │ RDS PostgreSQL  │   │ ECS Fargate │
              │   (Single-AZ)   │   │ Prometheus  │
              │      :5432      │   │   :9090     │
              └─────────────────┘   └─────────────┘

┌─────────────────────────────────────────────────────────────┐
│               Observability Stack (ECS Fargate)             │
│  ┌──────────────┐  ┌────────────┐  ┌──────────────┐         │
│  │   Grafana    │  │ Prometheus │  │  CloudWatch  │         │
│  │  Dashboards  │◄─┤  Metrics   │  │     Logs     │         │
│  │  :3000       │  │  :9090     │  │              │         │
│  └──────────────┘  └─────┬──────┘  └──────────────┘         │
│                          │ scrapes                          │
│         ┌────────────────┴────────────────┐                 │
│         ▼                                 ▼                 │
│   Backend /api/metrics              Frontend /metrics       │
│   (prom-client)                     (prom-client)           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│               Supporting Infrastructure                     │
│  ┌──────────────┐  ┌────────────┐  ┌──────────────┐         │
│  │   AWS EFS    │  │  AWS Cloud │  │   AWS S3     │         │
│  │  Persistent  │  │    Map     │  │  Profiling   │         │
│  │   Storage    │  │  Discovery │  │  Artifacts   │         │
│  └──────────────┘  └────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🌐 Network Architecture

### VPC Design

**CIDR:** `10.0.0.0/16`

**Subnets:**

**Public Subnets** (Internet-facing):
- `10.0.1.0/24` - us-east-1a - ALB, NAT Gateway
- `10.0.2.0/24` - us-east-1b - ALB, NAT Gateway

**Private Subnets** (Application):
- `10.0.10.0/24` - us-east-1a - ECS Tasks
- `10.0.11.0/24` - us-east-1b - ECS Tasks

**Database Subnets** (Isolated):
- `10.0.20.0/24` - us-east-1a - RDS Primary
- `10.0.21.0/24` - us-east-1b - RDS Standby

### Security Groups

**ALB Security Group:**
- Inbound: 443 (HTTPS) from 0.0.0.0/0
- Inbound: 80 (HTTP) from 0.0.0.0/0 (redirect to HTTPS)
- Outbound: All traffic to ECS Security Group

**ECS Security Group:**
- Inbound: 3000 (Frontend) from ALB SG
- Inbound: 3001 (Backend) from ALB SG
- Outbound: 443 to 0.0.0.0/0 (AWS services)
- Outbound: 5432 to RDS SG

**RDS Security Group:**
- Inbound: 5432 (PostgreSQL) from ECS SG only
- Outbound: None required

---

## 💻 Application Architecture

### Frontend (Next.js)

**Technology:**
- Next.js 16 (App Router)
- TypeScript
- Tailwind CSS
- Server-Side Rendering (SSR)

**Features:**
- Personal portfolio/about page
- Blog posts (MDX-based)
- Contact form
- Skills showcase
- Responsive design

**Container:**
- Base Image: `node:24-alpine`
- Port: 3000
- Health Check: `/api/health`

### Backend (Nest.js)

**Technology:**
- Nest.js 11.7
- TypeScript
- PostgreSQL (TypeORM)
- REST API

**API Endpoints:**
- `GET /health` - Health check
- `GET /api/posts` - Blog posts
- `POST /api/contact` - Contact form
- `GET /metrics` - Prometheus metrics

**Container:**
- Base Image: `node:24-alpine`
- Port: 3001
- Health Check: `/health`

### Database (PostgreSQL)

**Configuration:**
- Engine: PostgreSQL 15
- Instance: db.t3.micro (dev), db.t3.small (prod)
- Multi-AZ: Yes (production)
- Automated Backups: 7 days retention
- Encryption: At-rest (KMS)

**Schema:**
```sql
-- Blog Posts
CREATE TABLE posts (
  id UUID PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  content TEXT NOT NULL,
  published_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Contact Messages
CREATE TABLE contacts (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🔄 CI/CD Pipeline Architecture

### GitHub Actions Workflows

**1. Build & Test Pipeline** (`.github/workflows/build.yml`)

Triggers: Push to any branch

```
┌─────────────┐
│   Checkout  │
└──────┬──────┘
       │
┌──────▼──────┐
│  Install    │
│ Dependencies│
└──────┬──────┘
       │
┌──────▼──────┐
│    Lint     │
│   & Test    │
└──────┬──────┘
       │
┌──────▼──────┐
│    Build    │
│   Docker    │
│   Images    │
└─────────────┘
```

**2. Deploy to Dev** (`.github/workflows/deploy-dev.yml`)

Triggers: Push to `main` branch

```
┌─────────────┐
│   Build     │
│   & Test    │
└──────┬──────┘
       │
┌──────▼──────┐
│    Push     │
│   to ECR    │
└──────┬──────┘
       │
┌──────▼──────┐
│   Deploy    │
│   to ECS    │
│   (Dev)     │
└──────┬──────┘
       │
┌──────▼──────┐
│   Smoke     │
│    Test     │
└─────────────┘
```

**3. Deploy to Production** (`.github/workflows/deploy-prod.yml`)

Triggers: Manual approval (workflow_dispatch)

```
┌─────────────┐
│   Manual    │
│  Approval   │
└──────┬──────┘
       │
┌──────▼──────┐
│    Run      │
│  Terraform  │
│   (Prod)    │
└──────┬──────┘
       │
┌──────▼──────┐
│    Push     │
│   to ECR    │
└──────┬──────┘
       │
┌──────▼──────┐
│   Deploy    │
│   to ECS    │
│   (Prod)    │
└──────┬──────┘
       │
┌──────▼──────┐
│   Health    │
│    Check    │
└─────────────┘
```

---

## 📊 Observability Architecture

### Metrics Collection

**Prometheus:**
- Scrapes application `/metrics` endpoints
- Collects ECS container metrics
- Stores time-series data

**CloudWatch:**
- ALB metrics (requests, latency, errors)
- ECS metrics (CPU, memory, task count)
- RDS metrics (connections, queries, storage)

**Application Metrics:**
- HTTP request duration
- API endpoint latencies
- Database query performance
- Custom business metrics

### Grafana Dashboards

**1. Application Performance Dashboard**
- Request rate (requests/sec)
- Response times (p50, p95, p99)
- Error rate (4xx, 5xx)
- Active connections

**2. Infrastructure Health Dashboard**
- ECS task health
- CPU and memory utilization
- Network throughput
- Disk usage

**3. Database Performance Dashboard**
- Query performance
- Connection pool status
- Replication lag (if applicable)
- Storage utilization

**4. Business Metrics Dashboard**
- Page views
- Contact form submissions
- Blog post engagement

### Alerting Rules

**Critical Alerts:**
- Application down (no healthy targets)
- Database connection failures
- High error rate (>5% over 5min)
- High latency (p99 >2s)

**Warning Alerts:**
- High CPU (>80% over 10min)
- High memory (>85%)
- Disk space (>80%)
- Slow queries (>1s average)

---

## 🔒 Security Architecture

### Authentication & Authorization

**Application Level:**
- No authentication required for public site
- Admin endpoints protected (future enhancement)

**Infrastructure Level:**
- IAM roles for ECS tasks (least privilege)
- IAM roles for GitHub Actions (OIDC)
- No long-lived AWS credentials

### Data Encryption

**At Rest:**
- RDS encryption with AWS KMS
- S3 bucket encryption (for Terraform state)
- EBS volumes encrypted

**In Transit:**
- HTTPS only (enforced by ALB)
- TLS 1.2+ required
- Database connections encrypted

### Secrets Management

**AWS Secrets Manager:**
- Database credentials
- API keys
- Environment-specific secrets

**Access:**
- ECS tasks pull secrets at runtime
- No secrets in code or Docker images
- Rotation enabled for database credentials

### Network Security

**Defense in Depth:**
1. CloudFront (DDoS protection)
2. ALB (SSL termination, WAF)
3. Security Groups (least privilege)
4. Private subnets (no direct internet access)
5. NACLs (additional layer)

---

## 🌍 Multi-Environment Strategy

### Development Environment

**Purpose:** Active development and testing

**Characteristics:**
- Smaller instance sizes (cost-optimized)
- Auto-deploy from `main` branch
- Less restrictive monitoring
- Can be shut down overnight

**Resources:**
- ECS Tasks: 1 Fargate task per service
- RDS: db.t3.micro (single-AZ)
- ALB: Minimal configuration

### Production Environment

**Purpose:** Live user traffic

**Characteristics:**
- Production-grade instance sizes
- Manual deployment (approval required)
- Strict monitoring and alerting
- Multi-AZ for high availability

**Resources:**
- ECS Tasks: 2+ Fargate tasks per service
- RDS: db.t3.small (Multi-AZ)
- ALB: Full configuration with WAF

---

## 📦 Infrastructure as Code

### Terraform Structure

```
terraform/
├── modules/
│   ├── networking/          # VPC, subnets, security groups, NAT gateways
│   ├── compute/             # ECS cluster, ALB, task definitions, services
│   ├── database/            # RDS PostgreSQL instance
│   ├── cdn/                 # CloudFront distribution, ACM certificates
│   └── observability/       # Prometheus, Grafana, EFS, Cloud Map
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
├── scripts/
│   ├── setup-backend.sh     # Initialize S3/DynamoDB backend
│   ├── validate-all.sh      # Validate all environments
│   └── cost-estimate.sh     # Estimate infrastructure costs
└── README.md
```

**Total Resources:** 81 AWS resources (78 Terraform-managed + 3 ECR repos)

**State Management:**
- Backend: S3 with DynamoDB locking
- State file encrypted
- Separate state per environment

**Module Principles:**
- Reusable across environments
- Well-documented inputs/outputs
- Follows AWS best practices
- Tested and validated

---

## 📈 Scaling Strategy

### Horizontal Scaling

**ECS Auto Scaling:**
- Target CPU: 70%
- Target Memory: 80%
- Min tasks: 2 (prod), 1 (dev)
- Max tasks: 10 (prod), 2 (dev)

**RDS:**
- Read replicas for read-heavy workloads (future)
- Vertical scaling as needed

### Caching Strategy

**CloudFront:**
- Static assets cached at edge
- Cache TTL: 1 hour for dynamic, 1 day for static

**Application:**
- Redis cache for API responses (future)

---

## 💰 Cost Optimization

**Actual Monthly Costs (Development Environment - December 2025):**

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| ECS Fargate (Frontend) | 2 tasks, 0.5 vCPU, 1 GB | ~$17 |
| ECS Fargate (Backend) | 2 tasks, 0.5 vCPU, 1 GB | ~$17 |
| ECS Fargate (Prometheus) | 1 task, 0.5 vCPU, 1 GB | ~$17 |
| ECS Fargate (Grafana) | 1 task, 0.5 vCPU, 1 GB | ~$17 |
| RDS t4g.micro | Single-AZ PostgreSQL | ~$12 |
| NAT Gateways | 2 (one per AZ) | ~$32 |
| ALB | Multi-target routing | ~$20 |
| EFS Storage | ~5 GB (Prometheus + Grafana) | ~$2 |
| CloudFront | CDN with caching | ~$1 |
| Data transfer | Minimal | ~$3 |
| **Total** | | **~$118-125/month** |

**Cost Optimization Strategies (Already Implemented):**
- ARM-based RDS instance (t4g.micro vs t3.micro)
- EFS lifecycle policies for infrequent access
- CloudFront caching to reduce origin requests
- S3 lifecycle policies for profiling artifacts (7-day expiration)

**Additional Optimization Options:**
- Single NAT Gateway in dev: Save ~$32/month (reduced HA)
- Fargate Spot for observability: Save ~$12/month
- Schedule dev shutdown overnight: Save ~40%

---

## 🔄 Disaster Recovery

**RTO (Recovery Time Objective):** < 1 hour  
**RPO (Recovery Point Objective):** < 5 minutes

**Backup Strategy:**
- RDS automated backups (7 days)
- RDS snapshots (weekly, 30 days retention)
- Terraform state backed up
- Docker images in ECR

**Recovery Procedures:**
1. Database: Restore from snapshot
2. Application: Redeploy from ECR
3. Infrastructure: Re-run Terraform

---

## 📚 Documentation Standards

**Living Documentation:**
- Architecture decisions recorded (ADRs)
- Runbooks for common operations
- Terraform modules fully documented
- API documentation (OpenAPI/Swagger)

**Diagram Updates:**
- Update diagrams with infrastructure changes
- Version control all diagrams
- Use draw.io or Mermaid

---

## 🎯 Success Metrics

**Technical Metrics:**
- ✅ Infrastructure provisioning < 15 minutes
- ✅ Deployment time < 10 minutes
- ✅ Application uptime > 99.5%
- ✅ API latency p99 < 500ms

**DevOps Metrics:**
- ✅ Deployments per day: 3+
- ✅ Lead time for changes: < 1 hour
- ✅ MTTR: < 15 minutes
- ✅ Change failure rate: < 5%

---

## 📚 Related Documentation

- [Observability Architecture](../observability-architecture.md) - Prometheus + Grafana deep dive
- [Node.js Performance Dashboard Guide](../nodejs-performance-dashboard-guide.md) - Grafana panel interpretation
- [Deployment Runbook](../deployment-runbook.md) - Operational procedures
- [Node.js Profiling Lab](../labs/node-profiling-and-debugging.md) - Hands-on profiling exercises

---

**Last Updated:** December 26, 2025
**Version:** 2.0

### Changelog

#### v2.0 (December 26, 2025)
- Updated architecture diagram with observability stack (Prometheus, Grafana)
- Added actual cost breakdown (~$118-125/month)
- Added observability module to Terraform structure
- Added supporting infrastructure (EFS, Cloud Map, S3 profiling bucket)
- Added related documentation links
- Marked platform as production complete

#### v1.0 (October 23, 2025)
- Initial architecture documentation

