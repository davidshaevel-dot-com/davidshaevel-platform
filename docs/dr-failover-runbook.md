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
| **Failback Script** | `scripts/dr-failback.sh` |
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
AWS_PROFILE=davidshaevel-dev ./scripts/dr-validation.sh --verbose
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
AWS_PROFILE=davidshaevel-dev ./scripts/dr-failover.sh --dry-run

# If everything looks good, run without --dry-run
AWS_PROFILE=davidshaevel-dev ./scripts/dr-failover.sh
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

#### Option B: Update terraform.tfvars and Apply

Edit `terraform/environments/dr/terraform.tfvars` to set the activation values:

```hcl
# Set to true to activate full DR infrastructure
dr_activated = true

# Use the latest DR snapshot (from Step 3)
db_snapshot_identifier = "davidshaevel-dev-db-dr-YYYYMMDD-HHMMSS"

# Container images (use latest tags from DR ECR)
frontend_container_image = "108581769167.dkr.ecr.us-west-2.amazonaws.com/davidshaevel/frontend:<tag>"
backend_container_image  = "108581769167.dkr.ecr.us-west-2.amazonaws.com/davidshaevel/backend:<tag>"
grafana_image            = "108581769167.dkr.ecr.us-west-2.amazonaws.com/davidshaevel/grafana:<tag>"
```

Then run:

```bash
cd terraform/environments/dr
AWS_PROFILE=davidshaevel-dev terraform apply
```

**Note:** Review the plan carefully before typing "yes" to confirm.

#### Option C: Manual Terraform Activation with CLI Variables

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

**Get the DR ALB DNS name:**

```bash
# Option A: From Terraform output (if in terraform/environments/dr directory)
cd terraform/environments/dr
AWS_PROFILE=davidshaevel-dev terraform output -raw alb_dns_name

# Option B: Using AWS CLI directly
aws elbv2 describe-load-balancers \
  --names dr-davidshaevel-alb \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

**Update Cloudflare:**

1. **Log into Cloudflare Dashboard**: https://dash.cloudflare.com
2. **Select Domain**: davidshaevel.com
3. **Go to DNS Settings**
4. **Update CNAME record for `grafana`**:
   - **Name**: `grafana`
   - **Target**: `<DR-ALB-DNS-NAME>` (from command above, e.g., `dr-davidshaevel-alb-536355098.us-west-2.elb.amazonaws.com`)
   - **Proxy Status**: Proxied (orange cloud)
5. **Save Changes**

**Note:** Changes propagate within 1-5 minutes when proxied.

### Step 7: Verify DR Environment

Run the validation script again:

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dr-validation.sh --verbose
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

### Comprehensive Validation Tests

Run these tests to fully validate DR is operational:

```bash
# 1. Verify backend is running in DR region (check environment in response)
curl -s https://davidshaevel.com/api/health | jq '.environment'
# Expected: "dr"

# 2. Verify database connectivity
curl -s https://davidshaevel.com/api/health | jq '.database.status'
# Expected: "connected"

# 3. Test DR ALB directly (bypassing CloudFront)
DR_ALB=$(cd terraform/environments/dr && AWS_PROFILE=davidshaevel-dev terraform output -raw alb_dns_name)
curl -s -k "https://${DR_ALB}/api/health" | jq '{environment, database}'

# 4. Verify ECS task count
aws ecs describe-services \
  --cluster dr-davidshaevel-cluster \
  --services dr-davidshaevel-frontend dr-davidshaevel-backend dr-davidshaevel-prometheus dr-davidshaevel-grafana \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount}' \
  --output table

# 5. Verify RDS is available
aws rds describe-db-instances \
  --db-instance-identifier davidshaevel-dr-db \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'DBInstances[0].DBInstanceStatus'
# Expected: "available"

# 6. Check CloudFront origin is pointing to DR
aws cloudfront get-distribution \
  --id EJVDEMX0X00IG \
  --profile davidshaevel-dev \
  --query 'Distribution.DistributionConfig.Origins.Items[0].DomainName'
# Expected: Contains "us-west-2"

# 7. Verify Grafana is accessible via DR ALB
curl -s -k "https://${DR_ALB}/grafana/api/health" | jq '.'
# Note: Requires Cloudflare DNS update for grafana subdomain

# 8. Check Prometheus is scraping metrics
# (Access via Grafana Explore tab and run: up{job="backend"})
```

### Observability Stack Validation

After DR activation, verify the observability stack:

1. **Prometheus Verification**:
   - Access Grafana at https://grafana.davidshaevel.com (after DNS update)
   - Go to Explore → Select Prometheus datasource
   - Query: `up{job="backend"}` - should return value of 1
   - Query: `process_cpu_seconds_total` - should show backend/frontend metrics

2. **Grafana Dashboard Verification**:
   - Login to Grafana (credentials in AWS Secrets Manager)
   - Check that provisioned dashboards are available
   - Verify dashboards show live data from DR environment

3. **Get Grafana Admin Password**:

   > **⚠️ IMPORTANT:** The Grafana admin password is **regenerated each time DR is activated**.
   > You must retrieve the current password from Secrets Manager after each activation.
   > The secret name includes a timestamp suffix, so use the commands below to find and retrieve it.

   **Username:** `admin`

   **Find and retrieve the password:**
   ```bash
   # Step 1: Find the current Grafana password secret name
   aws secretsmanager list-secrets \
     --region us-west-2 \
     --profile davidshaevel-dev \
     --query "SecretList[?contains(Name, 'grafana-admin-password')].Name" \
     --output text

   # Step 2: Get the password (replace SECRET_NAME with output from Step 1)
   aws secretsmanager get-secret-value \
     --secret-id SECRET_NAME \
     --region us-west-2 \
     --profile davidshaevel-dev \
     --query 'SecretString' \
     --output text
   ```

   **One-liner to get the password:**
   ```bash
   SECRET_NAME=$(aws secretsmanager list-secrets \
     --region us-west-2 \
     --profile davidshaevel-dev \
     --query "SecretList[?contains(Name, 'grafana-admin-password')].Name" \
     --output text) && \
   aws secretsmanager get-secret-value \
     --secret-id "${SECRET_NAME}" \
     --region us-west-2 \
     --profile davidshaevel-dev \
     --query 'SecretString' \
     --output text
   ```

---

## Post-Activation Checklist

- [ ] All ECS services running with desired count
- [ ] RDS instance status is "available"
- [ ] Frontend loads at https://davidshaevel.com/
- [ ] Backend API responds at https://davidshaevel.com/api/health
- [ ] Cloudflare DNS updated for grafana.davidshaevel.com → DR ALB
- [ ] Grafana admin password retrieved from Secrets Manager (regenerated each activation!)
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

### Database Authentication Failed

If you see the following error in the DR backend ECS logs:

```
[Nest] 1 - ERROR [ExceptionHandler] error: password authentication failed for user "dbadmin"
```

**Root Cause:** The DR database secret credentials don't match the credentials in the restored RDS snapshot. When RDS restores from a snapshot, it preserves the credentials from the snapshot time. If the primary database password was changed after the snapshot was taken, or if the DR secret was never synced, authentication will fail.

**Fix:**

1. Retrieve the current credentials from the primary RDS-managed secret:

```bash
# Find the primary database secret ARN
aws rds describe-db-instances \
  --db-instance-identifier davidshaevel-dev-db \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text

# Get the credentials (replace ARN with actual value from above)
aws secretsmanager get-secret-value \
  --secret-id "rds!db-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'SecretString' \
  --output text | jq .
```

2. Update the DR secret with the correct credentials:

```bash
aws secretsmanager put-secret-value \
  --secret-id davidshaevel-dr-db-credentials \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --secret-string '{"username":"dbadmin","password":"<password-from-step-1>"}'
```

3. Force the backend service to redeploy and pick up the new credentials:

```bash
aws ecs update-service \
  --cluster dr-davidshaevel-cluster \
  --service dr-davidshaevel-backend \
  --force-new-deployment \
  --region us-west-2 \
  --profile davidshaevel-dev
```

4. Monitor the new task deployment:

```bash
aws ecs describe-services \
  --cluster dr-davidshaevel-cluster \
  --services dr-davidshaevel-backend \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'services[0].{running:runningCount,desired:desiredCount,pending:pendingCount}'
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

### CloudFront Still Pointing to Primary ALB After DR Activation

If `terraform apply` fails (e.g., due to CloudWatch Log Group already exists error), the `dr-failover.sh` script won't reach the CloudFront update step. You'll need to manually update CloudFront to point to the DR ALB.

**Check current CloudFront origin:**

```bash
aws cloudfront get-distribution \
  --id EJVDEMX0X00IG \
  --profile davidshaevel-dev \
  --query 'Distribution.DistributionConfig.Origins.Items[0].DomainName' \
  --output text
```

**Get the DR ALB DNS name:**

```bash
aws elbv2 describe-load-balancers \
  --names dr-davidshaevel-alb \
  --region us-west-2 \
  --profile davidshaevel-dev \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

**Update CloudFront origin to DR ALB:**

```bash
# Set the DR ALB DNS (use value from above command)
DR_ALB_DNS="dr-davidshaevel-alb-XXXXXXXXX.us-west-2.elb.amazonaws.com"

# Get current config and ETag
aws cloudfront get-distribution-config \
  --id EJVDEMX0X00IG \
  --profile davidshaevel-dev > /tmp/cf-config.json

ETAG=$(jq -r '.ETag' /tmp/cf-config.json)

# Update the origin domain name
jq --arg dr_alb "${DR_ALB_DNS}" \
  '.DistributionConfig.Origins.Items[0].DomainName = $dr_alb' \
  /tmp/cf-config.json | jq '.DistributionConfig' > /tmp/cf-config-updated.json

# Apply the update
aws cloudfront update-distribution \
  --id EJVDEMX0X00IG \
  --if-match "${ETAG}" \
  --distribution-config file:///tmp/cf-config-updated.json \
  --profile davidshaevel-dev

# Create cache invalidation
aws cloudfront create-invalidation \
  --distribution-id EJVDEMX0X00IG \
  --paths "/*" \
  --profile davidshaevel-dev

# Clean up temp files
rm /tmp/cf-config.json /tmp/cf-config-updated.json
```

**Note:** CloudFront deployments take ~5-10 minutes to complete.

---

## Failback Procedure

When the primary region is restored and healthy, use `scripts/dr-failback.sh` to return traffic to us-east-1.

### Step 1: Verify Primary Region is Healthy

Before initiating failback, confirm the primary region is fully operational:

```bash
# Check primary region availability
aws ec2 describe-availability-zones --region us-east-1 --profile davidshaevel-dev

# Check ECS services are running
aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend dev-davidshaevel-frontend dev-davidshaevel-prometheus dev-davidshaevel-grafana \
  --region us-east-1 \
  --profile davidshaevel-dev \
  --query 'services[*].{name:serviceName,running:runningCount}' \
  --output table

# Test primary ALB health (HTTPS with -k to skip cert validation for raw ALB DNS)
curl -Ik https://dev-davidshaevel-alb-85034469.us-east-1.elb.amazonaws.com/api/health
```

### Step 2: Run Failback Script

#### Option A: Using Failback Script (Recommended)

```bash
# Dry run first
AWS_PROFILE=davidshaevel-dev ./scripts/dr-failback.sh --dry-run

# Execute failback (keeps DR infrastructure running)
AWS_PROFILE=davidshaevel-dev ./scripts/dr-failback.sh

# Execute failback AND deactivate DR infrastructure
AWS_PROFILE=davidshaevel-dev ./scripts/dr-failback.sh --deactivate-dr
```

The script will:
1. Verify primary region and application health
2. Update CloudFront origin to primary ALB
3. Invalidate CloudFront cache
4. Optionally deactivate DR infrastructure

#### Option B: Manual Failback

```bash
# Get current CloudFront config
aws cloudfront get-distribution-config \
  --profile davidshaevel-dev \
  --id EJVDEMX0X00IG > /tmp/cf-config.json

# Extract ETag
ETAG=$(jq -r '.ETag' /tmp/cf-config.json)

# Update origin to primary ALB
PRIMARY_ALB="dev-davidshaevel-alb-85034469.us-east-1.elb.amazonaws.com"
jq --arg alb "$PRIMARY_ALB" '.DistributionConfig.Origins.Items[0].DomainName = $alb' /tmp/cf-config.json | \
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

### Step 3: Update Cloudflare DNS for Grafana

1. **Log into Cloudflare Dashboard**: https://dash.cloudflare.com
2. **Select Domain**: davidshaevel.com
3. **Go to DNS Settings**
4. **Update CNAME record for `grafana`**:
   - **Name**: `grafana`
   - **Target**: `dev-davidshaevel-alb-85034469.us-east-1.elb.amazonaws.com`
   - **Proxy Status**: Proxied (orange cloud)
5. **Save Changes**

### Step 4: Verify Primary Application

```bash
# Wait for CloudFront deployment (~5-10 min)
aws cloudfront get-distribution \
  --id EJVDEMX0X00IG \
  --profile davidshaevel-dev \
  --query 'Distribution.Status'

# Test endpoints
curl -I https://davidshaevel.com/api/health
curl -I https://davidshaevel.com/
curl -I https://grafana.davidshaevel.com/api/health
```

### Step 5: Deactivate DR Infrastructure (Optional)

If you didn't use `--deactivate-dr`, you can manually deactivate:

```bash
cd terraform/environments/dr
AWS_PROFILE=davidshaevel-dev terraform apply -var="dr_activated=false" -auto-approve
```

This returns DR to Pilot Light mode:
- Destroys VPC, ECS, RDS, ALB
- Keeps ECR replication, snapshot Lambda, KMS key

**Note:** Keep DR infrastructure running for a few hours after failback to ensure stability before deactivating.

---

## Post-Failback Checklist

- [ ] CloudFront deployment complete (status: Deployed)
- [ ] Primary frontend loads at https://davidshaevel.com/
- [ ] Primary backend API responds at https://davidshaevel.com/api/health
- [ ] Grafana accessible at https://grafana.davidshaevel.com
- [ ] Cloudflare DNS updated for grafana subdomain
- [ ] DR infrastructure deactivated (optional)
- [ ] Incident postmortem scheduled
- [ ] Stakeholders notified of return to normal operations

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

