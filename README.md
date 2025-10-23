# DavidShaevel.com Platform Engineering Portfolio

A full-stack web platform showcasing DevOps best practices, infrastructure automation, and platform engineering expertise.

## 🎯 Project Purpose

This project serves as both a personal website and a demonstration of production-ready DevOps practices, including:

- **Infrastructure as Code** with Terraform
- **CI/CD Automation** with GitHub Actions
- **Comprehensive Observability** with Grafana/Prometheus
- **Cloud-Native Architecture** on AWS
- **Production-Ready Security** and best practices

## 🏗️ Architecture

**Frontend:** Next.js 16 with TypeScript and Tailwind CSS  
**Backend:** Nest.js 11.7 with TypeScript and PostgreSQL  
**Infrastructure:** AWS (ECS, RDS, VPC, CloudFront, Route53)  
**IaC:** Terraform with modular design  
**CI/CD:** GitHub Actions  
**Monitoring:** Grafana + Prometheus + CloudWatch  
**Domain:** davidshaevel.com (managed in Cloudflare)

## 📁 Repository Structure

```
davidshaevel-platform/
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines
├── terraform/
│   ├── modules/           # Reusable Terraform modules
│   ├── environments/
│   │   ├── dev/          # Development environment
│   │   └── prod/         # Production environment
│   └── README.md
├── frontend/              # Next.js application
├── backend/               # Nest.js API
├── monitoring/            # Grafana/Prometheus configurations
├── docs/
│   ├── architecture/     # Architecture diagrams and decisions
│   ├── runbooks/        # Operational runbooks
│   └── deployment.md    # Deployment procedures
├── docker-compose.yml    # Local development environment
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Node.js 24+
- Docker and Docker Compose
- AWS CLI configured
- Terraform 1.5+

### Local Development

```bash
# Start local development environment
docker-compose up -d

# Frontend (Next.js)
cd frontend
npm install
npm run dev

# Backend (Nest.js)
cd backend
npm install
npm run start:dev
```

### Infrastructure Deployment

```bash
# Initialize Terraform
cd terraform/environments/dev
terraform init

# Plan infrastructure changes
terraform plan

# Apply infrastructure
terraform apply
```

## 📊 Monitoring

Access Grafana dashboards at: `https://grafana.davidshaevel.com`

**Key Dashboards:**
- Application Performance Metrics
- Infrastructure Health
- API Response Times
- Database Performance
- CI/CD Pipeline Status

## 🔒 Security

- **IAM:** Least privilege access with AWS IAM roles
- **Secrets:** AWS Secrets Manager for sensitive data
- **SSL/TLS:** Certificate management with AWS ACM
- **Network:** VPC with proper segmentation and security groups
- **Compliance:** Following AWS Well-Architected Framework

## 📈 DevOps Metrics

**Key Performance Indicators:**
- Deployment Frequency: Multiple times per day
- Lead Time for Changes: < 1 hour
- Mean Time to Recovery (MTTR): < 15 minutes
- Change Failure Rate: < 5%

## 🎓 Learning Outcomes

This project demonstrates:
- Multi-environment infrastructure management
- Automated CI/CD pipelines
- Comprehensive observability practices
- Security-first mindset
- Infrastructure automation
- Production incident response readiness

## 📝 Documentation

- [Architecture Overview](docs/architecture/overview.md)
- [Deployment Guide](docs/deployment.md)
- [Runbooks](docs/runbooks/)
- [Terraform Modules](terraform/README.md)

## 🛠️ Technology Stack

**Infrastructure:**
- AWS (VPC, ECS, RDS, S3, CloudFront, Route53)
- Terraform (Infrastructure as Code)
- Docker (Containerization)

**Application:**
- Next.js 16 (Frontend)
- Nest.js 11.7 (Backend API)
- PostgreSQL (Database)
- TypeScript (Language)

**DevOps:**
- GitHub Actions (CI/CD)
- Grafana (Dashboards)
- Prometheus (Metrics)
- CloudWatch (AWS Monitoring)
- AWS Secrets Manager (Secrets)

## 📞 Contact

**David Shaevel**  
Platform Engineer | DevOps Specialist  
Austin, Texas

---

**Project Timeline:** 3 days intensive build (Oct 23-25, 2025)  
**Status:** Active Development  
**AWS Account:** DavidShaevel.com Development Environment (108581769167)

