# Disaster Recovery Failover Runbook

Step-by-step procedures for activating the DR environment when the primary region (us-east-1) is unavailable.

**Last Updated:** January 10, 2026

---

## Quick Reference

| Item | Value |
|------|-------|
| **Primary Region** | us-east-1 |
| **DR Region** | us-west-2 |
| **Domain** | davidshaevel.com |
| **CloudFront Distribution** | EJVDEMX0X00IG |
| **Estimated Activation Time** | 30-45 minutes |
| **DR Terraform Directory** | `terraform/environments/dr/` |
| **Failover Script** | `scripts/dr-failover.sh` |
| **Validation Script** | `scripts/dr-validation.sh` |

---

## Pre-Requisites

Before initiating DR failover, ensure you have:

1. **AWS CLI** configured with `davidshaevel-dev` profile
2. **Terraform** installed (version 1.x+)
3. **Cloudflare Access** - Login credentials for DNS management
4. **AWS Console Access** - For CloudFront configuration verification
5. **Repository Access** - Clone of davidshaevel-platform repo

Verify AWS credentials:
```bash
aws sts get-caller-identity --profile davidshaevel-dev
```

---

## DR Architecture Overview

### Pilot Light Components (Always Running)

These components are always deployed in us-west-2:

- **ECR Replication**: Container images auto-replicated from us-east-1
- **KMS Key**: Encryption key for DR snapshots
- **Snapshot Copy Lambda**: Copies RDS snapshots from us-east-1 to us-west-2
- **EventBridge Rule**: Triggers snapshot copy on backup completion

### On-Demand Components (Deployed During Activation)

These are deployed only when DR is activated:

- **VPC** with public/private subnets across 2 AZs
- **RDS PostgreSQL** (restored from latest snapshot)
- **ECS Fargate Cluster** with frontend, backend, Prometheus, and Grafana services
- **Application Load Balancer** with HTTPS support
- **Service Discovery** (AWS Cloud Map)

---

## Failover Procedure

### Step 1: Assess the Situation

Before activating DR, confirm:

```bash
# Check if primary region is truly unavailable
aws ec2 describe-availability-zones --region us-east-1 --profile davidshaevel-dev

# Check primary application health
curl -I https://davidshaevel.com/api/health
curl -I https://grafana.davidshaevel.com/api/health
```

If both checks fail, proceed with DR activation.

### Step 2: Validate DR Readiness

Run the validation script to ensure DR components are healthy:

```bash
cd /path/to/davidshaevel-platform
./scripts/dr-validation.sh --verbose
```

Expected output in Pilot Light mode:
- AWS credentials valid
- DR infrastructure is in Pilot Light mode
- KMS key exists
- ECR repos have replicated images
- DR snapshots are available
- Lambda and EventBridge are active

### Step 3: Identify Latest DR Snapshot

```bash
aws rds describe-db-snapshots \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --snapshot-type manual \
  --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, \`davidshaevel-dev-db-dr-\`)] | sort_by(@, &SnapshotCreateTime) | [-1].{ID:DBSnapshotIdentifier,Status:Status,Created:SnapshotCreateTime}" \
  --output table
```

Note the snapshot identifier - you'll need it for activation.

### Step 4: Activate DR Infrastructure

#### Option A: Using Failover Script (Recommended)

```bash
# Dry run first to see the plan
./scripts/dr-failover.sh --dry-run

# If everything looks good, run without --dry-run
./scripts/dr-failover.sh
```

The script will:
1. Verify AWS credentials
2. Find latest DR snapshot
3. Find latest container images in DR ECR
4. Display activation plan
5. Ask for confirmation
6. Run Terraform apply
7. Update CloudFront origin to DR ALB
8. Invalidate CloudFront cache

#### Option B: Manual Terraform Activation

```bash
cd terraform/environments/dr

# Set variables
export SNAPSHOT_ID="davidshaevel-dev-db-dr-2026-01-10-00-15"
export ECR_REGISTRY="108581769167.dkr.ecr.us-west-2.amazonaws.com"
export BACKEND_TAG=$(aws ecr describe-images --repository-name davidshaevel/backend --region us-west-2 --profile davidshaevel-dev --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' --output text)
export FRONTEND_TAG=$(aws ecr describe-images --repository-name davidshaevel/frontend --region us-west-2 --profile davidshaevel-dev --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' --output text)
export GRAFANA_TAG=$(aws ecr describe-images --repository-name davidshaevel/grafana --region us-west-2 --profile davidshaevel-dev --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' --output text)

# Run Terraform apply
AWS_PROFILE=davidshaevel-dev terraform apply \
  -var="dr_activated=true" \
  -var="db_snapshot_identifier=${SNAPSHOT_ID}" \
  -var="backend_container_image=${ECR_REGISTRY}/davidshaevel/backend:${BACKEND_TAG}" \
  -var="frontend_container_image=${ECR_REGISTRY}/davidshaevel/frontend:${FRONTEND_TAG}" \
  -var="grafana_image=${ECR_REGISTRY}/davidshaevel/grafana:${GRAFANA_TAG}"
```

**Expected Duration:** ~25-35 minutes (RDS restore is the longest step)

### Step 5: Update CloudFront Origin

If not using the automated script, manually update CloudFront:

```bash
# Get DR ALB DNS name
cd terraform/environments/dr
ALB_DNS=$(AWS_PROFILE=davidshaevel-dev terraform output -raw alb_dns_name)
echo "DR ALB: $ALB_DNS"

# Get current CloudFront config
aws cloudfront get-distribution-config \
  --profile davidshaevel-dev \
  --id EJVDEMX0X00IG > /tmp/cf-config.json

# Extract ETag
ETAG=$(jq -r '.ETag' /tmp/cf-config.json)

# Update origin to DR ALB
jq --arg alb "$ALB_DNS" '.DistributionConfig.Origins.Items[0].DomainName = $alb' /tmp/cf-config.json | \
  jq '.DistributionConfig' > /tmp/cf-config-updated.json

# Apply update
aws cloudfront update-distribution \
  --profile davidshaevel-dev \
  --id EJVDEMX0X00IG \
  --if-match "$ETAG" \
  --distribution-config file:///tmp/cf-config-updated.json

# Invalidate cache
aws cloudfront create-invalidation \
  --profile davidshaevel-dev \
  --distribution-id EJVDEMX0X00IG \
  --paths "/*"
```

### Step 6: Update Cloudflare DNS for Grafana

Grafana uses a separate CNAME that points directly to the ALB.

1. **Log into Cloudflare Dashboard**: https://dash.cloudflare.com
2. **Select Domain**: davidshaevel.com
3. **Go to DNS Settings**
4. **Update CNAME record for `grafana`**:
   - **Name**: `grafana`
   - **Target**: `<DR-ALB-DNS-NAME>` (e.g., `dr-davidshaevel-alb-536355098.us-west-2.elb.amazonaws.com`)
   - **Proxy Status**: Proxied (orange cloud)
5. **Save Changes**

**Note:** Changes propagate within 1-5 minutes when proxied.

### Step 7: Verify DR Environment

Run the validation script again:

```bash
./scripts/dr-validation.sh --verbose
```

Expected results when DR is activated:
- All 17+ checks should pass
- VPC is available
- RDS is available
- ECS services are running
- ALB health check returns 200

Manual verification:

```bash
# Check all ECS services
aws ecs describe-services \
  --cluster dr-davidshaevel-cluster \
  --services dr-davidshaevel-frontend dr-davidshaevel-backend dr-davidshaevel-prometheus dr-davidshaevel-grafana \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount}' \
  --output table

# Test endpoints
curl -I https://davidshaevel.com/api/health
curl -I https://davidshaevel.com/
curl -I https://grafana.davidshaevel.com/api/health
```

---

## Post-Activation Checklist

- [ ] All ECS services running with desired count
- [ ] RDS instance status is "available"
- [ ] Frontend loads at https://davidshaevel.com/
- [ ] Backend API responds at https://davidshaevel.com/api/health
- [ ] Grafana accessible at https://grafana.davidshaevel.com
- [ ] Grafana dashboards showing data
- [ ] CloudFront distribution deployed (check status)
- [ ] Notify stakeholders of DR activation

---

## Monitoring During DR

### CloudWatch Logs

```bash
# Backend logs
aws logs tail /ecs/dr-davidshaevel/backend --since 30m --follow --profile davidshaevel-dev --region us-west-2

# Frontend logs
aws logs tail /ecs/dr-davidshaevel/frontend --since 30m --follow --profile davidshaevel-dev --region us-west-2

# Prometheus logs
aws logs tail /ecs/dr-davidshaevel/prometheus --since 30m --follow --profile davidshaevel-dev --region us-west-2

# Grafana logs
aws logs tail /ecs/dr-davidshaevel/grafana --since 30m --follow --profile davidshaevel-dev --region us-west-2
```

### Key DR Resources

| Resource | Name | Region |
|----------|------|--------|
| ECS Cluster | dr-davidshaevel-cluster | us-west-2 |
| Backend Service | dr-davidshaevel-backend | us-west-2 |
| Frontend Service | dr-davidshaevel-frontend | us-west-2 |
| Prometheus Service | dr-davidshaevel-prometheus | us-west-2 |
| Grafana Service | dr-davidshaevel-grafana | us-west-2 |
| RDS Instance | davidshaevel-dr-db | us-west-2 |
| ALB | dr-davidshaevel-alb | us-west-2 |

---

## Troubleshooting

### RDS Restore Taking Too Long

RDS snapshot restore typically takes 15-25 minutes. Monitor progress:

```bash
aws rds describe-db-instances \
  --db-instance-identifier davidshaevel-dr-db \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'DBInstances[0].DBInstanceStatus'
```

### ECS Tasks Not Starting

Check task status and stopped reason:

```bash
# List stopped tasks
aws ecs list-tasks \
  --cluster dr-davidshaevel-cluster \
  --desired-status STOPPED \
  --region us-west-2 \
  --profile davidshaevel-dev

# Describe stopped task to see reason
aws ecs describe-tasks \
  --cluster dr-davidshaevel-cluster \
  --tasks <task-arn> \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'tasks[0].stoppedReason'
```

### Grafana Login Issues

The Grafana admin password is stored in AWS Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id dr-davidshaevel-grafana-admin-password \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'SecretString' \
  --output text
```

### CloudFront Not Updating

Check deployment status:

```bash
aws cloudfront get-distribution \
  --id EJVDEMX0X00IG \
  --profile davidshaevel-dev \
  --query 'Distribution.Status'
```

If status is "InProgress", wait for deployment to complete (~5-10 minutes).

---

## Failback Procedure

When the primary region is restored, use `scripts/dr-failback.sh` to return traffic to us-east-1.

See [DR Failback Runbook](./dr-failback-runbook.md) (TBD) for detailed failback procedures.

---

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **AWS Support**: Support Center in AWS Console
- **Cloudflare Support**: https://support.cloudflare.com

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-01-10 | David Shaevel | Initial version |

