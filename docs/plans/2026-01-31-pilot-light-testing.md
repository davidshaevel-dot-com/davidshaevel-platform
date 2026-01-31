# AWS Pilot Light Testing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Test the complete AWS pilot light activation/deactivation cycle and optionally execute final deactivation to achieve ~$115/month cost savings.

**Architecture:** Vercel serves production traffic with Neon PostgreSQL. AWS dev environment can be activated from pilot light mode for skills practice, then deactivated back. Bidirectional data sync ensures database consistency.

**Tech Stack:** Terraform, AWS (ECS, RDS, CloudFront), Neon PostgreSQL, Vercel, Bash scripts

---

## Prerequisites

Before starting, verify:
- [ ] AWS credentials active (`AWS_PROFILE=davidshaevel-dev`)
- [ ] `NEON_DATABASE_URL` set in environment
- [ ] Vercel serving production traffic
- [ ] Current `dev_activated` status known

---

## Task 1: Validate Current State

**Goal:** Establish baseline before testing.

**Files:**
- Run: `scripts/dev-validation.sh`

**Step 1: Verify AWS credentials**

```bash
AWS_PROFILE=davidshaevel-dev aws sts get-caller-identity
```

Expected: Account 108581769167

**Step 2: Verify Vercel is serving production**

```bash
curl -sL https://davidshaevel.com/api/health | jq '.status'
```

Expected: `"healthy"`

**Step 3: Check current dev_activated status**

```bash
AWS_PROFILE=davidshaevel-dev terraform -chdir=terraform/environments/dev output -raw dev_activated 2>&1 | tee /tmp/terraform-output.log
```

Expected: `true` (currently activated)

**Step 4: Run dev-validation.sh**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dev-validation.sh 2>&1 | tee /tmp/dev-validation.log
```

Expected: All checks pass, mode shows "Full (activated)"

**Step 5: Record baseline state**

Note the following for comparison after testing:
- RDS projects count
- Neon projects count
- ECS service statuses
- Validation pass/fail counts

---

## Task 2: Test Deactivation Cycle (TT-102)

**Goal:** Deactivate AWS dev to pilot light mode and verify Vercel continues serving.

**Files:**
- Run: `scripts/sync-rds-to-neon.sh`
- Run: `scripts/dev-deactivate.sh`
- Run: `scripts/dev-validation.sh`

**Step 1: Dry-run RDS → Neon sync**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/sync-rds-to-neon.sh --dry-run 2>&1 | tee /tmp/sync-dry-run.log
```

Expected: Shows sync plan without making changes

**Step 2: Execute RDS → Neon sync**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/sync-rds-to-neon.sh 2>&1 | tee /tmp/sync-rds-to-neon.log
```

Expected:
- Dump created
- Uploaded to S3
- Restored to Neon
- Row counts match

**Step 3: Deactivate AWS dev**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dev-deactivate.sh 2>&1 | tee /tmp/dev-deactivate.log
```

Expected:
- Terraform destroys ~60-80 resources (ECS, ALB, CloudFront origins, etc.)
- ECR repos and S3 buckets remain
- RDS remains (always-on)

**Step 4: Verify pilot light state**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dev-validation.sh 2>&1 | tee /tmp/dev-validation-pilot.log
```

Expected: Mode shows "Pilot Light", all pilot light checks pass

**Step 5: Verify Vercel still serving**

```bash
curl -sL https://davidshaevel.com/api/health | jq
curl -sL https://davidshaevel.com/api/projects | jq 'length'
```

Expected: Both return successfully

**Step 6: Update Linear issue TT-102**

Mark TT-102 as Done if all steps passed.

---

## Task 3: Test Activation Cycle (TT-101)

**Goal:** Activate AWS dev from pilot light mode and verify all services come up.

**Files:**
- Run: `scripts/sync-neon-to-rds.sh`
- Run: `scripts/dev-activate.sh`
- Run: `scripts/dev-validation.sh`

**Step 1: Dry-run Neon → RDS sync**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/sync-neon-to-rds.sh --dry-run 2>&1 | tee /tmp/sync-neon-dry-run.log
```

Expected: Shows sync plan without making changes

**Step 2: Execute Neon → RDS sync**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/sync-neon-to-rds.sh 2>&1 | tee /tmp/sync-neon-to-rds.log
```

Expected:
- Dump created from Neon
- Uploaded to S3
- Restored to RDS
- Row counts match

**Step 3: Activate AWS dev**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dev-activate.sh 2>&1 | tee /tmp/dev-activate.log
```

Expected:
- Terraform creates ~60-80 resources
- ECS services start
- ALB becomes healthy
- CloudFront updated

**Step 4: Wait for ECS services to stabilize**

```bash
AWS_PROFILE=davidshaevel-dev aws ecs describe-services \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend dev-davidshaevel-frontend \
  --query 'services[*].[serviceName,runningCount,desiredCount]' \
  --output table
```

Expected: All services show runningCount = desiredCount

**Step 5: Verify full activation**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dev-validation.sh 2>&1 | tee /tmp/dev-validation-full.log
```

Expected: Mode shows "Full (activated)", all checks pass

**Step 6: Test AWS endpoints (optional)**

If DNS is switched to AWS:
```bash
curl -sL https://davidshaevel.com/api/health | jq
```

Or test ALB directly:
```bash
ALB_DNS=$(AWS_PROFILE=davidshaevel-dev terraform -chdir=terraform/environments/dev output -raw alb_dns_name 2>/dev/null)
curl -sk "https://${ALB_DNS}/api/health" | jq
```

**Step 7: Update Linear issue TT-101**

Mark TT-101 as Done if all steps passed.

---

## Task 4: Final Deactivation (TT-106) - OPTIONAL

**Goal:** Execute final deactivation to achieve ~$115/month cost savings.

**Prerequisites:**
- [ ] Task 2 (deactivation) tested successfully
- [ ] Task 3 (activation) tested successfully
- [ ] Decision made to proceed with final deactivation

**Step 1: Final RDS → Neon sync**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/sync-rds-to-neon.sh 2>&1 | tee /tmp/final-sync.log
```

**Step 2: Final deactivation**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dev-deactivate.sh 2>&1 | tee /tmp/final-deactivate.log
```

**Step 3: Verify final state**

```bash
AWS_PROFILE=davidshaevel-dev ./scripts/dev-validation.sh 2>&1 | tee /tmp/final-validation.log
```

Expected: Pilot Light mode, all checks pass

**Step 4: Verify Vercel serving production**

```bash
curl -sL https://davidshaevel.com/ -o /dev/null -w "%{http_code}\n"
curl -sL https://davidshaevel.com/api/health | jq '.status'
curl -sL https://davidshaevel.com/api/projects | jq 'length'
```

Expected: All return successfully

**Step 5: Update Linear issue TT-106**

Mark TT-106 as Done.

**Step 6: Commit any documentation updates**

If any docs were updated during testing:
```bash
git add docs/
git commit -m "docs(pilot-light): add testing session notes

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>

related-issues: TT-101, TT-102, TT-106"
git push
```

---

## Summary Checklist

| Task | Description | Status |
|------|-------------|--------|
| 1 | Validate current state | ⬜ |
| 2 | Test deactivation cycle (TT-102) | ⬜ |
| 3 | Test activation cycle (TT-101) | ⬜ |
| 4 | Final deactivation (TT-106) - OPTIONAL | ⬜ |

---

## Rollback Procedures

**If deactivation fails mid-way:**
```bash
AWS_PROFILE=davidshaevel-dev terraform -chdir=terraform/environments/dev apply -var="dev_activated=true" -auto-approve
```

**If Vercel stops working:**
```bash
./scripts/vercel-dns-switch.sh --status
# Check DNS configuration
```

**If data sync fails:**
- Check S3 bucket for dump file
- Check pg_restore exit code in logs
- Manually verify row counts in both databases

---

## Expected Outcomes

**After successful testing:**
- Confidence that activation/deactivation scripts work
- Bidirectional data sync verified
- Ready for final deactivation

**After final deactivation:**
- Monthly AWS cost: ~$2-5 (down from ~$118-126)
- Vercel serving all production traffic
- AWS dev in pilot light, re-activatable anytime
