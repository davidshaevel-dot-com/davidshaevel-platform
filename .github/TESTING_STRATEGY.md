# CI/CD Testing Strategy

This document outlines the testing approach for GitHub Actions CI/CD workflows before merging to main.

## Testing Philosophy

**Goal:** Validate workflows work correctly without impacting production services.

**Approach:** Progressive testing from safest to most realistic:
1. **Workflow validation** - Syntax and configuration checks
2. **Test job execution** - Run linter and tests in isolation
3. **Build job execution** - Build and push Docker image to ECR
4. **Full deployment** - Deploy to dev environment (controlled)

---

## Phase 2: Backend Workflow Testing

### Prerequisites

- ✅ PR #26 created with backend workflow
- ✅ Terraform lifecycle blocks applied to dev environment
- ✅ GitHub dev environment configured with 9 secrets
- ✅ AWS IAM user with least-privilege permissions created

### Test Plan

> **Important:** GitHub Actions workflows must be on the default branch (main) before they can be registered and tested. This means we'll merge PR #26 first, then immediately test using workflow_dispatch.

#### Test 1: Workflow Syntax Validation
**Purpose:** Ensure workflow YAML is valid before merging

**Method:**
```bash
# Manual inspection of workflow file
cat .github/workflows/backend-deploy.yml

# Check for common issues:
# - Valid YAML syntax
# - Correct job dependencies (needs: test, needs: build)
# - Proper environment variable usage
# - Valid GitHub Actions syntax (${{ }})
```

**Validation Checklist:**
- ✅ Valid YAML syntax (no tabs, proper indentation)
- ✅ Three jobs defined: test, build, deploy
- ✅ Job dependencies correct: build needs test, deploy needs build
- ✅ Triggers configured: push to main (backend/**), workflow_dispatch
- ✅ Environment secrets used: ${{ secrets.AWS_ACCESS_KEY_ID }}, etc.
- ✅ Concurrency control defined
- ✅ Working directory specified for backend commands

**Expected Result:** All validation checks pass

**Status:** ✅ **PASSED** - Workflow syntax validated

---

#### Test 2: Merge PR and Register Workflow
**Purpose:** Merge PR #26 to register workflow with GitHub Actions

**Method:**
```bash
# Review PR one final time
gh pr view 26

# Merge PR using squash merge (clean history)
gh pr merge 26 --squash --delete-branch

# Verify workflow is now registered
gh workflow list

# View workflow details
gh workflow view "Backend CI/CD"
```

**Expected Result:**
- PR #26 merged successfully
- Branch `ci-cd/backend-workflow-tt31` deleted
- Workflow "Backend CI/CD" appears in workflow list
- Workflow shows correct triggers and jobs

**Note:** This merge will NOT trigger the workflow because:
- No changes to `backend/**` in this PR (only workflow file)
- Workflow only triggers on backend code changes
- We'll manually trigger it in Test 3

**Status:** ⏳ Pending

---

#### Test 3: Manual Workflow Trigger (Full Deployment)
**Purpose:** Test complete workflow (test + build + deploy) using workflow_dispatch

**Method:**
```bash
# Trigger workflow manually for dev environment
gh workflow run "Backend CI/CD" -f environment=dev

# Wait a few seconds for run to start
sleep 5

# Monitor workflow execution in real-time
gh run watch

# After completion, view detailed logs
gh run view --log

# Get run URL for Linear
gh run list --workflow="Backend CI/CD" --limit 1 --json databaseId,url --jq '.[0].url'
```

**What Gets Tested:**
- ✅ **Test Job:**
  - Node.js 22 setup
  - npm ci (dependency installation)
  - npm run lint (ESLint)
  - npm run test (Jest)
- ✅ **Build Job:**
  - AWS credentials configuration
  - ECR login
  - Docker build
  - Docker tag (sha + latest)
  - Docker push to ECR
- ✅ **Deploy Job:**
  - Download current task definition
  - Update task definition with new image
  - Deploy to ECS service
  - Wait for service stability (10 min timeout)
  - Service URL retrieval
  - GitHub deployment summary

**Post-Deployment Verification:**
```bash
# Verify ECS service updated
AWS_PROFILE=davidshaevel-dev aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend \
  --query 'services[0].[serviceName,status,runningCount,desiredCount,taskDefinition]' \
  --output table

# Get service URL
AWS_PROFILE=davidshaevel-dev aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend \
  --query 'services[0].loadBalancers[0].targetGroupArn' \
  --output text > /tmp/tg_arn.txt

TG_ARN=$(cat /tmp/tg_arn.txt)
ALB_ARN=$(AWS_PROFILE=davidshaevel-dev aws elbv2 describe-target-groups \
  --target-group-arns $TG_ARN \
  --query 'TargetGroups[0].LoadBalancerArns[0]' \
  --output text)

ALB_DNS=$(AWS_PROFILE=davidshaevel-dev aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "Backend URL: http://${ALB_DNS}/api"

# Test health endpoint
curl -i http://${ALB_DNS}/api/health
```

**Expected Result:**
- ✅ All three jobs complete successfully (green checkmarks)
- ✅ Test job passes all linting and unit tests
- ✅ Build job pushes image to ECR with two tags (sha + latest)
- ✅ Deploy job updates ECS service to new task definition
- ✅ ECS service reaches stable state within 10 minutes
- ✅ Service shows 1/1 running tasks (or configured desired count)
- ✅ Health endpoint returns 200 OK
- ✅ GitHub deployment summary shows correct details

**Rollback Plan:** If deployment fails:
1. Review workflow logs: `gh run view --log`
2. Check ECS service events:
   ```bash
   AWS_PROFILE=davidshaevel-dev aws ecs describe-services \
     --cluster dev-davidshaevel-cluster \
     --services dev-davidshaevel-backend \
     --query 'services[0].events[:5]'
   ```
3. Verify IAM permissions are correct
4. If service is unhealthy: ECS will auto-rollback to previous task definition
5. If manual rollback needed:
   ```bash
   # List recent task definitions
   AWS_PROFILE=davidshaevel-dev aws ecs list-task-definitions \
     --family-prefix dev-davidshaevel-backend \
     --sort DESC --max-items 5

   # Rollback to previous revision
   AWS_PROFILE=davidshaevel-dev aws ecs update-service \
     --cluster dev-davidshaevel-cluster \
     --service dev-davidshaevel-backend \
     --task-definition dev-davidshaevel-backend:<previous-revision>
   ```

**Status:** ⏳ Pending

---

#### Test 4: Terraform Drift Verification
**Purpose:** Confirm lifecycle blocks prevent Terraform from detecting drift

**Method:**
```bash
# After successful deployment, run terraform plan
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/terraform/environments/dev
AWS_PROFILE=davidshaevel-dev terraform plan

# Expected output: No changes, no drift warnings
```

**Expected Result:**
```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

**If Drift Detected:**
- Review lifecycle block implementation
- Check if task_definition is in ignore_changes list
- Verify Terraform applied lifecycle blocks before workflow ran

**Status:** ⏳ Pending

---

### Success Criteria

All tests must pass to consider Phase 2 complete:

- [ ] **Test 1:** Workflow syntax validation passes
- [ ] **Test 2:** PR #26 merged successfully, workflow registered
- [ ] **Test 3:** Manual deployment completes, service healthy
- [ ] **Test 4:** No Terraform drift detected after deployment

### Test Results

#### Test 1: Workflow Syntax Validation
**Date:** 2025-11-04
**Result:** ✅ **PASSED**
**Notes:**
- Workflow file syntax validated manually
- All YAML syntax correct
- Job dependencies properly configured (build needs test, deploy needs build)
- GitHub Actions syntax correct (${{ }} expressions)
- Triggers configured correctly
- Concurrency control present

---

#### Test 2: Merge PR and Register Workflow
**Date:** _TBD_
**Result:** ⏳ Pending
**PR:** https://github.com/davidshaevel-dot-com/davidshaevel-platform/pull/26
**Notes:**

---

#### Test 3: Manual Workflow Trigger (Full Deployment)
**Date:** _TBD_
**Result:** ⏳ Pending
**Workflow Run:** _URL_
**Notes:**

---

#### Test 4: Terraform Drift Verification
**Date:** _TBD_
**Result:** ⏳ Pending
**Notes:**

---

## Post-Test Actions

After all tests pass:

1. ✅ Document test results above
2. ✅ Update Linear TT-31 with test results and workflow run URL
3. ✅ Add Testing Strategy document to repository
4. ✅ Mark Phase 2 as complete in Linear
5. ✅ Proceed to Phase 3: Frontend CI/CD Workflow

---

## Test Environment Cleanup

If testing reveals issues and PR needs significant rework:

1. **Revert Terraform Changes:**
   ```bash
   cd terraform/modules/compute
   git checkout main -- main.tf
   cd ../../environments/dev
   AWS_PROFILE=davidshaevel-dev terraform apply
   ```

2. **Close PR:**
   ```bash
   gh pr close 26
   ```

3. **Create New Branch with Fixes:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b ci-cd/backend-workflow-fixes
   ```

---

## Notes and Observations

### Security Validation
- ✅ Workflow uses GitHub environment secrets (not repository secrets)
- ✅ AWS credentials are masked in logs
- ✅ IAM permissions are least-privilege (ECR + ECS only)
- ✅ No secrets hardcoded in workflow file

### Performance Observations
- Test job duration: _TBD_
- Build job duration: _TBD_
- Deploy job duration: _TBD_
- Total workflow duration: _TBD_

### Potential Improvements
- Consider caching npm dependencies across workflow runs
- Evaluate Docker layer caching for faster builds
- Monitor ECR storage costs (image cleanup policy)

---

## Related Documentation

- [CI/CD Setup Manual Steps](./.github/CICD_SETUP_MANUAL_STEPS.md)
- [Backend Workflow](./workflows/backend-deploy.yml)
- [Terraform Compute Module](../terraform/modules/compute/main.tf)
- [CI/CD IAM Module](../terraform/modules/cicd-iam/README.md)

