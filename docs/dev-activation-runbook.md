# Dev Environment Activation/Deactivation Runbook

Step-by-step procedures for activating and deactivating the AWS dev environment (us-east-1). The dev environment operates in **pilot light mode** by default (`dev_activated=false`), preserving infrastructure while destroying compute resources to minimize costs.

> **Architecture Context (February 2026):** Production traffic is served by **Vercel** (frontend + backend + Neon PostgreSQL). The AWS dev environment is only activated for development, testing, or as a fallback if Vercel is unavailable. For DR failover to us-west-2, see [dr-failover-runbook.md](dr-failover-runbook.md).

**Last Updated:** February 6, 2026

---

## Quick Reference

| Item | Value |
|------|-------|
| **Normal Production** | Vercel (frontend + backend + Neon DB) |
| **Dev AWS Region** | us-east-1 |
| **Domain** | davidshaevel.com |
| **DNS Provider** | Cloudflare |
| **Activation Script** | `scripts/dev-activate.sh` |
| **Deactivation Script** | `scripts/dev-deactivate.sh` |
| **Validation Script** | `scripts/dev-validation.sh` |
| **DNS Switch Script** | `scripts/vercel-dns-switch.sh` |
| **Terraform Directory** | `terraform/environments/dev/` |
| **Estimated Activation Time** | ~15-20 minutes |
| **Estimated Deactivation Time** | ~10-15 minutes |

---

## What Gets Activated/Deactivated

### Always-On (Pilot Light)

These resources exist regardless of `dev_activated` state:

| Resource | Purpose |
|----------|---------|
| VPC + Subnets | Network structure (10.0.0.0/16) |
| Security Groups | Firewall rules |
| RDS PostgreSQL (db.t3.micro) | Database with data |
| ECR Repositories (3) | Container image storage |
| S3 Backup Bucket | Database backup storage |
| CI/CD IAM | GitHub Actions permissions |

### Conditional (Only When Activated)

These resources are created on activation and destroyed on deactivation (~93 resources):

| Resource | Purpose |
|----------|---------|
| NAT Gateways (2) | Egress for private subnets |
| ECS Fargate Cluster | Container orchestration |
| Frontend ECS Service (2 tasks) | Next.js application |
| Backend ECS Service (2 tasks) | NestJS API |
| Prometheus ECS Service | Metrics collection |
| Grafana ECS Service | Metrics dashboards |
| Application Load Balancer | HTTPS traffic routing |
| CloudFront Distribution | CDN + SSL termination |
| ACM Certificate | SSL certificate (covers grafana subdomain) |
| Cloud Map Namespace | Service discovery |
| EFS + S3 Config | Observability storage |

### Cost Comparison

| Mode | Monthly Cost |
|------|-------------|
| Pilot Light (`dev_activated=false`) | ~$17 |
| Full Activation (`dev_activated=true`) | ~$118 |
| Vercel (production, always running) | ~$0 (free tier) |

---

## Prerequisites

Before activating or deactivating, ensure you have:

1. **AWS CLI** configured with `davidshaevel-dev` profile
2. **Terraform** installed (version 1.x+)
3. **Cloudflare environment variables** set in `.envrc`:
   - `CLOUDFLARE_API_TOKEN` — API token with DNS edit permissions
   - `CLOUDFLARE_ZONE_ID` — Zone ID for davidshaevel.com
4. **Repository** cloned with `terraform.tfvars` configured in `terraform/environments/dev/`

Verify AWS credentials:
```bash
aws sts get-caller-identity --profile davidshaevel-dev
```

Source environment variables:
```bash
source .envrc
```

---

## Activation Procedure

Use this when you need the full AWS dev environment running (development, testing, or as a production fallback).

### Step 1: Pre-Flight Check

```bash
# Verify AWS credentials
aws sts get-caller-identity --profile davidshaevel-dev

# Check current state
./scripts/dev-validation.sh --verbose
```

Confirm the output shows "Pilot Light" mode and that always-on resources (VPC, RDS, ECR) are healthy.

### Step 2: Activate AWS Infrastructure

#### Option A: Using Activation Script (Recommended)

```bash
# Dry run first to see the plan
./scripts/dev-activate.sh --dry-run

# Activate (will prompt for confirmation)
./scripts/dev-activate.sh

# Activate with auto-approve (no confirmation prompt)
./scripts/dev-activate.sh --yes

# Activate and sync Neon data to RDS first
./scripts/dev-activate.sh --sync-data
```

The script will:
1. Verify AWS credentials
2. Check that environment is currently in pilot light mode
3. Query ECR for latest tagged container images (frontend + backend)
4. Verify RDS instance is available
5. Optionally sync Neon → RDS data (if `--sync-data` flag)
6. Display activation plan (~81 resources to create)
7. Run `terraform apply -var="dev_activated=true"` with container image variables
8. Display ALB DNS and CloudFront domain on completion

#### Option B: Manual Terraform Activation

```bash
cd terraform/environments/dev

# Get latest container image tags
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile davidshaevel-dev)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
BACKEND_TAG=$(aws ecr describe-images \
  --repository-name davidshaevel/backend \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
  --output text)
FRONTEND_TAG=$(aws ecr describe-images \
  --repository-name davidshaevel/frontend \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
  --output text)

echo "Backend: ${BACKEND_TAG}, Frontend: ${FRONTEND_TAG}"

# Run Terraform
AWS_PROFILE=davidshaevel-dev terraform apply \
  -var="dev_activated=true" \
  -var="backend_container_image=${ECR_REGISTRY}/davidshaevel/backend:${BACKEND_TAG}" \
  -var="frontend_container_image=${ECR_REGISTRY}/davidshaevel/frontend:${FRONTEND_TAG}"
```

**Expected Duration:** ~15-20 minutes (CloudFront distribution deployment is the longest step)

### Step 3: Validate Activation

```bash
# Run full validation
./scripts/dev-validation.sh --verbose
```

Expected: All 11-12 checks pass, mode shows "Full".

Manual verification:
```bash
# Check ECS services
aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend dev-davidshaevel-frontend dev-davidshaevel-prometheus dev-davidshaevel-grafana \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount}' \
  --output table

# Test ALB health directly
ALB_DNS=$(cd terraform/environments/dev && AWS_PROFILE=davidshaevel-dev terraform output -raw alb_dns_name)
curl -Ik "https://${ALB_DNS}/api/health"
```

### Step 4: Switch DNS to AWS (Optional)

Only do this if you want production traffic on AWS instead of Vercel:

```bash
# Preview DNS change
./scripts/vercel-dns-switch.sh --status

# Switch DNS from Vercel to AWS CloudFront
./scripts/vercel-dns-switch.sh --to-aws

# Verify the switch
./scripts/vercel-dns-switch.sh --status
```

This updates Cloudflare DNS:
- `davidshaevel.com` → CNAME to CloudFront distribution
- `www.davidshaevel.com` → CNAME to CloudFront distribution
- `grafana.davidshaevel.com` → CNAME to ALB

### Step 5: Verify End-to-End (If DNS Switched)

```bash
# Test public endpoints (may take 1-5 min for DNS propagation)
curl -I https://davidshaevel.com/api/health
curl -I https://davidshaevel.com/
curl -I https://grafana.davidshaevel.com/api/health
```

---

## Post-Activation Checklist

- [ ] `dev-validation.sh --verbose` passes all checks
- [ ] ECS services running with desired task count
- [ ] RDS instance status is "available"
- [ ] ALB health check returns 200
- [ ] CloudFront distribution deployed (if applicable)
- [ ] DNS switched to AWS (if needed) — `vercel-dns-switch.sh --status`
- [ ] Grafana accessible (retrieve admin password from Secrets Manager)

### Grafana Admin Password

```bash
# The password may change between activations — one-liner to retrieve it
SECRET_NAME=$(aws secretsmanager list-secrets \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query "SecretList[?contains(Name, 'grafana')].Name" \
  --output text) && \
aws secretsmanager get-secret-value \
  --secret-id "${SECRET_NAME}" \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'SecretString' \
  --output text
```

---

## Deactivation Procedure

Use this to return the dev environment to pilot light mode and reduce costs.

### Step 1: Ensure Production is on Vercel

**Critical:** Before deactivating, verify that production traffic is NOT on AWS:

```bash
# Check current DNS target
./scripts/vercel-dns-switch.sh --status
```

If DNS is pointing to AWS, switch back to Vercel first:

```bash
./scripts/vercel-dns-switch.sh --to-vercel

# Verify Vercel is serving traffic
curl -I https://davidshaevel.com/api/health
```

### Step 2: Deactivate AWS Infrastructure

#### Option A: Using Deactivation Script (Recommended)

```bash
# Dry run first
./scripts/dev-deactivate.sh --dry-run

# Deactivate (will prompt for confirmation)
./scripts/dev-deactivate.sh

# Deactivate with auto-approve
./scripts/dev-deactivate.sh --yes

# Sync RDS data to Neon before deactivating
./scripts/dev-deactivate.sh --sync-data
```

The script will:
1. Verify AWS credentials
2. Check that environment is currently activated
3. Verify production DNS is NOT on AWS (safety check)
4. Optionally sync RDS → Neon data (if `--sync-data` flag)
5. Display deactivation plan (~81 resources to destroy)
6. Run `terraform apply -var="dev_activated=false"`
7. Display preserved resources and cost savings

**Safety mechanism:** The script checks HTTP headers on `davidshaevel.com` to confirm Vercel is serving traffic. If AWS is detected as serving production, deactivation is blocked (overridable with `--yes`).

#### Option B: Manual Terraform Deactivation

```bash
cd terraform/environments/dev
AWS_PROFILE=davidshaevel-dev terraform apply -var="dev_activated=false"
```

**Expected Duration:** ~10-15 minutes

### Step 3: Validate Pilot Light Mode

```bash
./scripts/dev-validation.sh --verbose
```

Expected: Mode shows "Pilot Light", always-on resources healthy, conditional resources absent.

```bash
# Verify production is still working on Vercel
curl -I https://davidshaevel.com/api/health
curl -I https://davidshaevel.com/
```

---

## Post-Deactivation Checklist

- [ ] `dev-validation.sh --verbose` passes pilot light checks
- [ ] Production (Vercel) is serving traffic — `vercel-dns-switch.sh --status`
- [ ] https://davidshaevel.com/ loads correctly
- [ ] https://davidshaevel.com/api/health returns 200

### Resources Preserved (Pilot Light)

| Resource | Status |
|----------|--------|
| VPC (10.0.0.0/16) | Available |
| RDS PostgreSQL | Available |
| ECR Repositories (3) | Images preserved |
| S3 Backup Bucket | Backups preserved |
| CI/CD IAM | Active |

### Resources Destroyed

| Resource | Notes |
|----------|-------|
| NAT Gateways (2) + Route Tables | Recreated on activation (~5 min) |
| ECS Cluster + 4 Services | Recreated on activation |
| ALB + Target Groups | Recreated on activation |
| CloudFront Distribution | Recreated on activation (~15 min) |
| Cloud Map Namespace | Recreated on activation |
| EFS + S3 Config | Grafana config lost, re-provisioned on activation |

---

## Data Synchronization

### Neon → RDS (Before Activation)

If you need RDS data current with Neon (production database):

```bash
./scripts/dev-activate.sh --sync-data
```

Or manually with the sync script (if available):
```bash
# Export from Neon
pg_dump "$NEON_DATABASE_URL" --no-owner --no-acl > /tmp/neon-export.sql

# Import to RDS (requires RDS to be running)
RDS_HOST=$(cd terraform/environments/dev && AWS_PROFILE=davidshaevel-dev terraform output -raw db_host)

# Retrieve the RDS password from Secrets Manager
SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier davidshaevel-dev-db \
  --region us-east-1 --profile davidshaevel-dev \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
RDS_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "${SECRET_ARN}" --region us-east-1 --profile davidshaevel-dev \
  --query 'SecretString' --output text | jq -r .password)

PGPASSWORD="${RDS_PASSWORD}" psql -h "${RDS_HOST}" -p 5432 -U dbadmin -d davidshaevel < /tmp/neon-export.sql
```

### RDS → Neon (Before Deactivation)

If you made data changes on RDS that need to persist to production:

```bash
./scripts/dev-deactivate.sh --sync-data
```

---

## Troubleshooting

### Activation Script Says "Already Activated"

The script checks Terraform state for `dev_activated`. If state is stale:

```bash
cd terraform/environments/dev
AWS_PROFILE=davidshaevel-dev terraform refresh
```

### ECS Tasks Not Starting After Activation

```bash
# Check stopped tasks
aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --desired-status STOPPED \
  --region us-east-1 \
  --profile davidshaevel-dev

# Get stopped reason
aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks <task-arn> \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'tasks[0].stoppedReason'
```

Common causes:
- **No container images in ECR**: Push images first or check ECR tags
- **Database connection failed**: Verify RDS is available and security groups allow ECS access
- **Secrets not found**: Check AWS Secrets Manager for required secrets

### CloudFront Distribution Slow to Deploy

CloudFront can take 10-15 minutes to deploy. Check status:

```bash
aws cloudfront list-distributions \
  --profile davidshaevel-dev \
  --query "DistributionList.Items[?contains(Aliases.Items, 'davidshaevel.com')].{Id:Id,Status:Status}" \
  --output table
```

### Deactivation Blocked by Safety Check

If the script blocks deactivation because it detects AWS is serving production:

1. Switch DNS to Vercel first: `./scripts/vercel-dns-switch.sh --to-vercel`
2. Wait for DNS propagation (~1-5 minutes)
3. Retry deactivation

Or override with `--yes` if you've manually verified safety.

### RDS Database Authentication After Activation

If backend can't connect to RDS after activation, the password may have rotated:

```bash
# One-liner to find the RDS secret ARN and retrieve credentials
SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier davidshaevel-dev-db \
  --region us-east-1 --profile davidshaevel-dev \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text) && \
aws secretsmanager get-secret-value \
  --secret-id "${SECRET_ARN}" \
  --region us-east-1 --profile davidshaevel-dev \
  --query 'SecretString' --output text | jq .
```

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-02-06 | David Shaevel | NAT Gateways moved to conditional resources (TT-136) |
| 2026-02-06 | David Shaevel | Initial version (TT-104) |
