# Security Group Drift Analysis and Fix

**Date:** October 26, 2025
**Issue:** Persistent Terraform drift with security group egress rules
**Status:** Root cause identified, fix proposed

---

## Problem Statement

After implementing security groups in PR #10 (Step 6), Terraform consistently shows drift:
- Plans to add 6 egress rules on every `terraform plan`
- Rules exist in AWS but Terraform state shows them missing
- Running `terraform apply` temporarily fixes it, but drift recurs

---

## Root Cause

**Conflict between inline and separate rule management:**

1. Security groups defined with `egress = []` to remove default "allow all" rule
2. Separate `aws_vpc_security_group_egress_rule` resources manage actual rules
3. Terraform tries to reconcile the security group's `egress = []` with AWS reality
4. AWS shows egress rules (created by separate resources)
5. Terraform sees this as drift: "I specified zero inline rules, but AWS has rules!"

### Why This Happens

When you use:
```hcl
resource "aws_security_group" "alb" {
  egress = []  # <-- Tells Terraform "manage inline egress, expect zero"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id = aws_security_group.alb.id
  # <-- Creates an egress rule attached to the security group
}
```

Terraform sees two conflicting sources of truth:
- Security group resource: "I manage egress inline, and I say there are zero rules"
- Separate rule resource: "I created a rule on this security group"
- AWS reality: Security group has 1 egress rule

Result: Constant drift

---

## The Proper Solution

### Option 1: Use `ignore_changes` Lifecycle (RECOMMENDED)

Tell Terraform to ignore inline rule changes since we're managing rules separately:

```hcl
resource "aws_security_group" "alb" {
  name_prefix = "${var.environment}-${var.project_name}-alb-sg-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Note: Rules are managed by separate aws_vpc_security_group_*_rule resources
  # We use ignore_changes to prevent drift

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-alb-sg"
    Tier = "public"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [egress, ingress]  # <-- THE FIX
  }
}
```

**Benefits:**
- ✅ No drift - Terraform ignores inline rule state
- ✅ Clean separation - Rules managed only by separate resources
- ✅ Best practice for complex security group configurations
- ✅ No actual infrastructure changes needed

**Trade-offs:**
- Terraform won't detect manual inline rule additions (acceptable for our use case)
- Must use separate rule resources for all rules (we already do this)

### Option 2: Use All Inline Rules (NOT RECOMMENDED)

Remove separate rule resources and manage everything inline:

```hcl
resource "aws_security_group" "alb" {
  # ... other config ...

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port                = 3000
    to_port                  = 3000
    protocol                 = "tcp"
    security_groups          = [aws_security_group.app_frontend.id]
  }
}
```

**Why we DON'T want this:**
- ❌ Less granular control
- ❌ Harder to manage complex rule sets
- ❌ Can cause resource recreation issues
- ❌ Requires refactoring existing code

---

## Implementation Plan

### Changes Required

**File:** `terraform/modules/networking/main.tf`

**Lines to modify:**
- Line 313-315: ALB security group lifecycle
- Line 396-398: Frontend security group lifecycle
- Line 464-466: Backend security group lifecycle
- Line 547-549: Database security group lifecycle

**Change from:**
```hcl
lifecycle {
  create_before_destroy = true
}
```

**Change to:**
```hcl
lifecycle {
  create_before_destroy = true
  ignore_changes        = [egress, ingress]
}
```

**Optional cleanup:**
Remove `egress = []` lines (306, 389, 457, 540) since they're now meaningless with ignore_changes.
Or keep them as documentation that we intentionally don't use inline rules.

### Testing Plan

1. **Make changes** to networking module
2. **Run terraform plan** - should show 4 security groups being updated in-place
3. **Run terraform apply** - applies lifecycle changes
4. **Run terraform plan again** - should show **zero drift**
5. **Wait 1 hour** - verify drift doesn't recur
6. **Commit fix** to a security-fix branch

---

## Why This is the Right Fix

### Comparison to "Run Apply Multiple Times"

**Old approach (treating symptoms):**
- Temporary fix that doesn't address root cause
- Requires manual intervention on every plan
- Wastes time and creates confusion
- Documented as "may recur"

**New approach (fixing root cause):**
- Addresses the fundamental design conflict
- Permanent fix with no recurrence
- Follows Terraform best practices
- Clean separation of concerns

### Terraform Best Practices

From HashiCorp documentation:

> "When using separate rule resources (`aws_security_group_rule` or
> `aws_vpc_security_group_*_rule`), you should not use the `ingress` and
> `egress` arguments on the `aws_security_group` resource. To prevent conflicts,
> use the `ignore_changes` lifecycle meta-argument."

We're following this exact pattern.

---

## Alternative Considered: `revoke_rules_on_delete`

Another option is to use `revoke_rules_on_delete = false`:

```hcl
resource "aws_security_group" "alb" {
  revoke_rules_on_delete = false  # Don't revoke rules when SG is destroyed

  lifecycle {
    ignore_changes = [egress, ingress]
  }
}
```

**Decision:** Not needed for our use case
- We're not frequently destroying security groups
- Default behavior (revoke on delete) is safer
- Adds complexity without benefit

---

## Expected Outcome

After applying this fix:

1. **Immediate effect:**
   - `terraform plan` shows 4 security groups updated (lifecycle change only)
   - No actual AWS infrastructure changes
   - Terraform state updated to ignore inline rules

2. **Long-term effect:**
   - ✅ Zero drift on subsequent plans
   - ✅ Clean, predictable Terraform behavior
   - ✅ Rules still managed by separate resources
   - ✅ Security posture unchanged

3. **Verification:**
   - All 6 egress rules continue to exist in AWS
   - All 7 ingress rules continue to exist in AWS
   - Terraform state matches AWS reality
   - No phantom resources

---

## Implementation Timeline

**Branch:** `claude/fix-security-group-drift`

**Estimated time:** 15 minutes

**Steps:**
1. Create fix branch
2. Update 4 security group lifecycle blocks
3. Optional: Remove or comment `egress = []` lines
4. Test with plan/apply
5. Verify no drift
6. Commit with detailed message
7. Can merge to main directly (low risk change) or create PR

**Decision:** Since this is blocking TT-22 work, and it's a low-risk change (only lifecycle metadata), we can:
- Fix it in a quick commit on main
- OR create a dedicated PR if we want documentation
- OR include it in the TT-22 PR as a prerequisite fix

**Recommendation:** Quick fix on main branch now, document in AGENT_HANDOFF.md

---

## Documentation Updates Needed

After fix:
- Update `.claude/AGENT_HANDOFF.md` - remove from "Known Issues", add to "Issues Resolved"
- Update `terraform/modules/networking/README.md` - add note about lifecycle ignore_changes
- Remove drift documentation from "may recur" to "fixed permanently"

---

## Lessons Learned

1. **Don't mix inline and separate rule management** - Choose one approach
2. **Use lifecycle ignore_changes when using separate rules** - Terraform best practice
3. **Understand Terraform's resource model** - Who owns what state
4. **Symptoms vs root cause** - Running apply repeatedly treats symptoms
5. **Document design decisions** - Why we use separate rules (granularity, clarity)

---

## References

- [AWS Security Group Terraform Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
- [Terraform Lifecycle Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [AWS VPC Security Group Rule Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule)

---

**Status:** Ready to implement
**Risk:** Low (lifecycle metadata change only)
**Impact:** Eliminates persistent drift issue
**Next Step:** Apply fix before proceeding with TT-22
