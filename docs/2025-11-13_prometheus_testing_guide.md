# Prometheus Testing Guide

**Date:** November 13, 2025
**Purpose:** Instructions for testing Prometheus ECS deployment

---

## Quick Start

### Option 1: Automated Test Script (Recommended)

```bash
cd /Users/dshaevel/workspace-ds/davidshaevel-platform

# Run the test script
./scripts/test-prometheus-deployment.sh
```

The script will automatically:
- ✅ Check ECS service status
- ✅ Verify task health
- ✅ Analyze CloudWatch logs
- ✅ Validate service discovery configuration
- ⏳ Test HTTP endpoints (requires ECS Exec - see below)
- ⏳ Test DNS resolution (requires backend container access)

---

## Session Manager Plugin Installation (Optional)

The Session Manager plugin enables ECS Exec for direct container access.

### Manual Installation (Requires sudo password)

```bash
# Install via Homebrew
brew install --cask session-manager-plugin

# Verify installation
session-manager-plugin --version
```

**Note:** This step is optional. The test script works without it, but HTTP endpoint tests will be skipped.

---

## Testing Without Session Manager Plugin

You can verify Prometheus functionality without installing the plugin:

### 1. CloudWatch Logs Verification

```bash
# View recent Prometheus logs
AWS_PROFILE=davidshaevel-dev aws logs tail \
  /ecs/dev-davidshaevel/prometheus \
  --since 30m \
  --follow \
  --region us-east-1

# Look for these success indicators:
# - "Server is ready to receive web requests"
# - "TSDB started"
# - "Completed loading of configuration file"
```

### 2. ECS Service Status

```bash
# Check service health
AWS_PROFILE=davidshaevel-dev aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-prometheus \
  --region us-east-1 \
  --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

### 3. Task Health Check

```bash
# Get task details
TASK_ARN=$(AWS_PROFILE=davidshaevel-dev aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-prometheus \
  --region us-east-1 \
  --query 'taskArns[0]' \
  --output text)

# Check container health
AWS_PROFILE=davidshaevel-dev aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks $TASK_ARN \
  --region us-east-1 \
  --query 'tasks[0].containers[?name==`prometheus`].[name,lastStatus,healthStatus]' \
  --output table
```

---

## Manual HTTP Endpoint Testing

If you have VPC access (VPN, bastion host, or another container):

### Health Endpoints

```bash
# Direct IP access (replace with actual task IP)
curl http://10.0.11.31:9090/-/healthy
curl http://10.0.11.31:9090/-/ready

# Service discovery DNS
curl http://prometheus.davidshaevel.local:9090/-/healthy
curl http://prometheus.davidshaevel.local:9090/-/ready
```

### Status Endpoints

```bash
# Configuration
curl http://prometheus.davidshaevel.local:9090/api/v1/status/config | jq .

# Runtime info
curl http://prometheus.davidshaevel.local:9090/api/v1/status/runtimeinfo | jq .

# Targets
curl http://prometheus.davidshaevel.local:9090/api/v1/targets | jq .
```

### Metrics Endpoints

```bash
# Prometheus's own metrics
curl http://prometheus.davidshaevel.local:9090/metrics

# Query API
curl 'http://prometheus.davidshaevel.local:9090/api/v1/query?query=up' | jq .

# List all metric names
curl http://prometheus.davidshaevel.local:9090/api/v1/label/__name__/values | jq .
```

---

## Enable ECS Exec for Future Testing

To enable direct container access without VPN/bastion:

### 1. Update Terraform Configuration

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
# Enable ECS Exec for Prometheus debugging
enable_prometheus_ecs_exec = true
```

### 2. Apply Changes

```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

### 3. Update Service

```bash
# Force new deployment to pick up ECS Exec setting
AWS_PROFILE=davidshaevel-dev aws ecs update-service \
  --cluster dev-davidshaevel-cluster \
  --service dev-davidshaevel-prometheus \
  --force-new-deployment \
  --region us-east-1
```

### 4. Test ECS Exec

```bash
# Get current task ARN
TASK_ARN=$(AWS_PROFILE=davidshaevel-dev aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-prometheus \
  --region us-east-1 \
  --query 'taskArns[0]' \
  --output text)

# Connect to container
AWS_PROFILE=davidshaevel-dev aws ecs execute-command \
  --cluster dev-davidshaevel-cluster \
  --task $TASK_ARN \
  --container prometheus \
  --interactive \
  --command "/bin/sh" \
  --region us-east-1
```

---

## Troubleshooting

### Issue: "SessionManagerPlugin is not found"

**Solution:**
```bash
# Install the plugin manually (requires sudo)
brew install --cask session-manager-plugin

# Or skip ECS Exec tests - they're optional
```

---

### Issue: "ECS Exec not enabled on task"

**Solution:**
1. Set `enable_prometheus_ecs_exec = true` in terraform.tfvars
2. Run `terraform apply`
3. Force service redeployment (see above)

---

### Issue: Can't access Prometheus endpoints

**Possible causes:**

1. **Not in VPC:** Prometheus is in private subnet, requires VPC access
   - Use ECS Exec (recommended)
   - Set up VPN or bastion host
   - Test from another ECS container (backend/frontend)

2. **Security groups:** Verify security group rules
   ```bash
   # Check Prometheus security group
   AWS_PROFILE=davidshaevel-dev aws ec2 describe-security-groups \
     --filters "Name=tag:Name,Values=*prometheus*" \
     --region us-east-1 \
     --query 'SecurityGroups[*].[GroupId,GroupName,IpPermissions]' \
     --output json
   ```

3. **Service discovery not registered:** Wait 30-60 seconds after task starts
   ```bash
   # Check instance registration
   AWS_PROFILE=davidshaevel-dev aws servicediscovery list-instances \
     --service-id srv-dezgezviduqdpmvg \
     --region us-east-1
   ```

---

## Test Script Details

The automated test script (`test-prometheus-deployment.sh`) performs:

### Pre-flight Checks
- ✅ AWS CLI installed
- ✅ AWS credentials valid
- ✅ Session Manager plugin (optional)

### Test 1: ECS Service Status
- Service status (ACTIVE)
- Running task count vs desired count
- Deployment rollout state

### Test 2: Task Health Status
- Prometheus container status (RUNNING)
- Health check status (HEALTHY)
- Init container status (STOPPED - expected)
- Task IP address

### Test 3: CloudWatch Logs
- Recent log streams exist
- Startup messages present
- Error count analysis

### Test 4: Service Discovery
- Namespace configuration
- Service registration
- Instance count

### Test 5: HTTP Endpoints (Requires ECS Exec)
- `/-/healthy` endpoint
- `/-/ready` endpoint
- `/api/v1/targets` API

### Test 6: DNS Resolution (Requires Backend)
- Service discovery DNS resolution
- HTTP requests via service discovery

---

## Expected Test Results

### Minimal Success (Without ECS Exec)
```
✓ ECS service is healthy
✓ Prometheus task is healthy
✓ Prometheus started successfully (log verification)
✓ No error messages in logs
✓ Service discovery configured
```

### Full Success (With ECS Exec)
```
✓ ECS service is healthy
✓ Prometheus task is healthy
✓ Prometheus started successfully (log verification)
✓ No error messages in logs
✓ Service discovery configured with instances
✓ Health endpoint responding: Prometheus is Healthy
✓ Ready endpoint responding: Prometheus is Ready
✓ Targets API endpoint responding
✓ DNS resolution successful from backend container
✓ HTTP request successful from backend (Status: 200)
```

---

## Next Steps After Verification

Once Prometheus is verified working:

1. **Configure Backend Metrics:**
   - Add `/metrics` endpoint to backend service
   - Verify Prometheus is scraping backend

2. **Configure Frontend Metrics:**
   - Add metrics endpoint to frontend
   - Verify scraping configuration

3. **Test Service Discovery:**
   - Confirm targets appear in `/api/v1/targets`
   - Verify metrics collection

4. **Access Web UI:**
   - Set up ALB or port forwarding
   - Access Prometheus web UI
   - Test queries and visualization

5. **Set Up Alerting:**
   - Configure alert rules
   - Set up Alertmanager (future phase)

---

## Quick Reference Commands

```bash
# Run automated test suite
./scripts/test-prometheus-deployment.sh

# View live logs
AWS_PROFILE=davidshaevel-dev aws logs tail \
  /ecs/dev-davidshaevel/prometheus --follow --region us-east-1

# Check service status
AWS_PROFILE=davidshaevel-dev aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-prometheus \
  --region us-east-1 | jq '.services[0] | {name, status, runningCount, desiredCount}'

# Get task IP
AWS_PROFILE=davidshaevel-dev aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks $(aws ecs list-tasks --cluster dev-davidshaevel-cluster \
    --service-name dev-davidshaevel-prometheus --query 'taskArns[0]' --output text) \
  --region us-east-1 \
  --query 'tasks[0].containers[0].networkInterfaces[0].privateIpv4Address' \
  --output text

# Force service redeployment
AWS_PROFILE=davidshaevel-dev aws ecs update-service \
  --cluster dev-davidshaevel-cluster \
  --service dev-davidshaevel-prometheus \
  --force-new-deployment \
  --region us-east-1
```

---

**Last Updated:** November 13, 2025
**Related Documents:**
- [2025-11-13_prometheus_verification_results.md](2025-11-13_prometheus_verification_results.md)
- [../scripts/test-prometheus-deployment.sh](../scripts/test-prometheus-deployment.sh)
