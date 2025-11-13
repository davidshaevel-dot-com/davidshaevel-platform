# ECS Exec Deployment Learnings - November 13, 2025

**Task:** Enable ECS Exec for Prometheus ECS service
**Status:** Deployment successful, ECS Exec troubleshooting in progress

---

## What We Learned

### 1. EFS File Locking Issue with Prometheus

**Problem:**
When deploying a new Prometheus task while an old task is still running, both tasks try to access the same EFS volume. Prometheus uses file-based database locking, which creates a deadlock:

```
ts=2025-11-13T22:32:37.042Z caller=main.go:1159 level=error
err="opening storage failed: lock DB directory: resource temporarily unavailable"
```

**Why It Happens:**
- ECS deployment strategy: New task must become HEALTHY before old task stops
- Prometheus requirement: Only one instance can hold the database lock
- Result: New task can't start because old task holds the lock
- Result: Old task won't stop because new task isn't healthy
- **Deadlock!**

**Solution:**
Manually stop the old task to release the EFS lock, allowing the new task to start:

```bash
# Stop old task manually
aws ecs stop-task \
  --cluster dev-davidshaevel-cluster \
  --task <old-task-id> \
  --reason "Manual stop to allow new deployment to proceed"

# ECS will automatically start a new task
# Wait for deployment to complete
```

**Future Prevention:**
This issue will occur on EVERY Prometheus deployment. Possible solutions:

1. **Accept Manual Intervention** (current approach)
   - Stop old task manually during each deployment
   - Simple, works reliably
   - Requires manual step

2. **Use Deployment Circuit Breaker** (recommended long-term)
   - Configure ECS to automatically rollback failed deployments
   - Set minimum healthy percent to 0
   - Allows old task to stop before new task must be healthy

3. **Pre-Stop Hook** (complex)
   - Container lifecycle hook to gracefully shut down Prometheus
   - Release locks before container stops
   - Requires custom scripting

---

### 2. Terraform State vs. AWS Reality

**Discovery:**
- `terraform state show` showed `enable_execute_command = true`
- `aws ecs describe-services` also showed `enableExecuteCommand: True`
- But running tasks still had ECS Exec disabled!

**Root Cause:**
ECS Exec is enabled at the SERVICE level, but tasks started BEFORE it was enabled don't inherit the setting. Only NEW tasks get ECS Exec.

**Lesson:**
When enabling ECS Exec, you MUST force a new deployment:

```bash
aws ecs update-service \
  --cluster <cluster> \
  --service <service> \
  --force-new-deployment
```

---

### 3. ECS Exec Configuration Already Exists

**Discovery:**
The Prometheus observability module already had full ECS Exec support configured:

```hcl
# terraform/modules/observability/variables.tf
variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging Prometheus tasks"
  type        = bool
  default     = false
}

# terraform/modules/observability/main.tf (line 517)
resource "aws_ecs_service" "prometheus" {
  ...
  enable_execute_command = var.enable_ecs_exec
  ...
}

# terraform/environments/dev/main.tf (line 275)
module "observability" {
  ...
  enable_ecs_exec = var.enable_prometheus_ecs_exec
  ...
}
```

**What We Did:**
Simply added one line to `terraform.tfvars`:

```hcl
enable_prometheus_ecs_exec = true
```

No terraform changes were needed - the infrastructure was already set up correctly!

---

### 4. ECS Exec "TargetNotConnectedException" Error

**Current Issue:**
After successfully deploying a new task with `enableExecuteCommand = true`, ECS Exec commands fail:

```
An error occurred (TargetNotConnectedException) when calling the ExecuteCommand operation:
The execute command failed due to an internal error. Try again later.
```

**Task Status:**
- `enableExecuteCommand`: `true` ✅
- Container Status: `RUNNING` ✅
- Health Status: `HEALTHY` ✅

**Possible Causes:**

1. **SSM Agent Not Installed in Container**
   - Fargate Platform Version must be 1.4.0 or later
   - SSM agent is automatically injected by AWS
   - Check platform version

2. **IAM Permissions Missing**
   - Task execution role needs SSM permissions
   - Task role might need additional permissions
   - Check IAM policies

3. **SSM Agent Not Ready Yet**
   - Agent might take 30-60 seconds to initialize
   - Try waiting longer before executing commands

4. **Network/Security Group Issues**
   - SSM requires outbound HTTPS (443) to AWS endpoints
   - Check security group egress rules

**Next Steps:**
- Verify Fargate platform version
- Check task execution role IAM permissions
- Wait longer and retry
- Check CloudWatch logs for SSM agent messages

---

## Deployment Timeline

**22:24** - Added `enable_prometheus_ecs_exec = true` to terraform.tfvars
**22:25** - Ran `terraform plan` - showed no changes (already enabled)
**22:26** - Forced new deployment with `aws ecs update-service --force-new-deployment`
**22:27-22:32** - New task stuck in PENDING, old task still running
**22:32** - Discovered EFS lock error in CloudWatch Logs
**22:33** - Manually stopped old task (70f05430...)
**22:33-22:35** - New task (b483c64d...) started and became HEALTHY
**22:35** - Deployment COMPLETED ✅
**22:36-22:37** - ECS Exec attempts failing with TargetNotConnectedException

---

## Current State

**Prometheus Service:**
- Service: `dev-davidshaevel-prometheus`
- Status: `ACTIVE`
- Desired Count: 1
- Running Count: 1
- Deployment: `COMPLETED`
- Enable Execute Command: `True` ✅

**Current Task:**
- Task ID: `b483c64d26044da4a545f6bdde554eca`
- Status: `RUNNING`
- Health: `HEALTHY`
- Enable Execute Command: `true` ✅

**ECS Exec:**
- Session Manager Plugin: Installed ✅
- Service Configuration: Enabled ✅
- Task Configuration: Enabled ✅
- **Connection Status:** Failing ❌ (TargetNotConnectedException)

---

## Files Modified

1. **terraform/environments/dev/terraform.tfvars**
   - Added: `enable_prometheus_ecs_exec = true`
   - Location: Lines 62-66 (Prometheus Observability Configuration section)

---

## Commands Used

```bash
# 1. Check current ECS Exec status
aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-prometheus \
  --query 'services[0].enableExecuteCommand'

# 2. Force new deployment
aws ecs update-service \
  --cluster dev-davidshaevel-cluster \
  --service dev-davidshaevel-prometheus \
  --force-new-deployment

# 3. Monitor deployment
aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-prometheus \
  --query 'services[0].[runningCount,deployments[0].rolloutState]'

# 4. Check task status
aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-prometheus

# 5. Check CloudWatch logs for errors
aws logs get-log-events \
  --log-group-name /ecs/dev-davidshaevel/prometheus \
  --log-stream-name "prometheus/prometheus/<task-id>"

# 6. Manually stop old task (to resolve EFS lock)
aws ecs stop-task \
  --cluster dev-davidshaevel-cluster \
  --task <old-task-id> \
  --reason "Manual stop to allow new deployment to proceed"

# 7. Verify new task has ECS Exec enabled
aws ecs describe-tasks \
  --cluster dev-davidshaevel-cluster \
  --tasks <new-task-id> \
  --query 'tasks[0].enableExecuteCommand'

# 8. Attempt ECS Exec (currently failing)
aws ecs execute-command \
  --cluster dev-davidshaevel-cluster \
  --task <task-id> \
  --container prometheus \
  --interactive \
  --command "/bin/sh"
```

---

## Recommendations

### Immediate

1. **Investigate ECS Exec TargetNotConnectedException:**
   - Check Fargate platform version
   - Verify IAM permissions for SSM
   - Wait longer for SSM agent initialization
   - Check security group egress rules

2. **Test Alternative Access Methods:**
   - Try accessing from backend container (if it has network access)
   - Consider temporary bastion host
   - Use CloudWatch Logs for verification

### Short-term

1. **Document EFS Lock Workaround:**
   - Add to deployment runbook
   - Create script to automate old task stop + wait for new deployment

2. **Configure Deployment Circuit Breaker:**
   - Set minimum healthy percent to 0
   - Allow deployments to proceed without old task being healthy first

3. **Add Pre-Deployment Validation:**
   - Check for running tasks before deployment
   - Warn about manual intervention needed

### Long-term

1. **Evaluate Prometheus High Availability:**
   - Consider multiple Prometheus instances with different storage
   - Implement Thanos for multi-instance aggregation
   - Use remote write to separate storage backend

2. **Automate EFS Lock Resolution:**
   - Custom deployment script
   - Lambda function triggered on deployment events
   - ECS task lifecycle hooks

---

## Success Criteria

**Achieved ✅:**
- [x] ECS Exec enabled in terraform configuration
- [x] New Prometheus task deployed with ECS Exec enabled
- [x] Task is RUNNING and HEALTHY
- [x] Service deployment COMPLETED
- [x] Identified and documented EFS locking issue

**Remaining ❌:**
- [ ] ECS Exec commands successfully connecting to container
- [ ] HTTP endpoints tested via ECS Exec
- [ ] Full test script execution with all tests passing

---

**Next Session Focus:**
1. Resolve ECS Exec TargetNotConnectedException
2. Successfully test Prometheus HTTP endpoints
3. Run full automated test script
4. Update verification documentation with endpoint test results

---

**Last Updated:** November 13, 2025 (22:37 CT)
**Related Issues:** TT-25 Phase 5 - Prometheus ECS Service Deployment
