# Session Agenda - February 6, 2026

## Session Goals

1. **TT-104:** Update documentation for Vercel-primary architecture
2. **Cost Reduction:** Reduce AWS pilot light costs from ~$50-60/month to ~$2-5/month

---

## Part 1: TT-104 - Documentation Updates

**Status:** In Progress | **Priority:** Medium

### Checklist (from issue)

- [ ] README.md - Update architecture section, add Vercel info
- [ ] CLAUDE.md - Add Vercel deployment details, update scripts section
- [ ] docs/dr-failover-runbook.md - Update for Vercel as primary
- [ ] Create docs/dev-activation-runbook.md - New runbook for AWS activation
- [ ] Update .envrc.example - Add Neon connection string
- [ ] Update terraform READMEs if needed

### Assessment of What's Already Done

Several items have been partially or fully completed through incremental updates:

| Item | Status | Notes |
|------|--------|-------|
| README.md architecture | Partially done | Current state updated (Feb 2), but architecture diagram still shows AWS-only flow |
| CLAUDE.md | Done | Vercel deployment, scripts, completed issues all documented |
| CLAUDE.local.md | Done | Vercel details, cost summary, session notes all current |
| .envrc.example | Partially done | Has Cloudflare vars, needs Neon/Vercel additions |
| docs/dr-failover-runbook.md | Needs update | References CloudFront as primary, needs Vercel context |
| docs/dev-activation-runbook.md | Not started | New document needed |
| Terraform READMEs | Low priority | Module docs still accurate for module behavior |

### Plan

1. Update README.md architecture diagram to show Vercel-primary with AWS pilot light
2. Update docs/dr-failover-runbook.md for Vercel-primary context
3. Create docs/dev-activation-runbook.md with activation/deactivation procedures
4. Update .envrc.example with Neon/Vercel variables
5. Mark TT-104 as Done

**Estimated time:** 1-2 hours

---

## Part 2: AWS Cost Reduction

### Current Pilot Light Costs (~$50-60/month)

| Component | Monthly Cost | Can Reduce? |
|-----------|-------------|-------------|
| NAT Gateways (2x) | ~$65 | Yes - disable in pilot light |
| RDS PostgreSQL (db.t3.micro) | ~$16 | Yes - stop or destroy |
| VPC/Networking | Minimal | No - needed for structure |
| S3 buckets | ~$1 | No - cheap, needed for backups |
| ECR repositories | Free | No - already free |

### Option A: Disable NAT Gateways in Pilot Light (saves ~$65/month)

**Finding:** The networking module already supports `enable_nat_gateway = false`. RDS does NOT depend on NAT Gateways (no egress rules, fully isolated in private subnets).

**Implementation:** One-line change in `terraform/environments/dev/main.tf`:

```hcl
# Line ~328: Change from hardcoded true to conditional
enable_nat_gateway = var.dev_activated  # Was: true
```

**Impact:**
- Saves: ~$65/month in pilot light mode
- RDS still works (no NAT dependency)
- VPC structure preserved
- Adds ~5 min to activation time (NAT Gateway creation)
- No module changes needed

**Risk:** Low. Networking module already handles this. DR environment already uses `single_nat_gateway = true` as a cost pattern.

### Option B: Stop or Remove RDS (saves ~$16/month)

Three sub-options:

**B1: Stop RDS instance (saves ~$16/month compute, still pays ~$2/month storage)**
- AWS allows stopping RDS for up to 7 days, then auto-restarts
- Would need a Lambda or manual process to re-stop every 7 days
- Preserves data and instance configuration
- Quick restart (~5 min)

**B2: Destroy RDS via Terraform (saves ~$16/month)**
- Set database module `count = var.dev_activated ? 1 : 0`
- Data preserved in automated snapshots and S3 backups
- Activation requires snapshot restore (~10-15 min)
- More complex than B1 but fully automated via Terraform

**B3: Keep RDS running (saves $0)**
- Simplest approach, always ready for activation
- Data always current for DR snapshot replication
- $16/month is relatively low

### Recommendation

| Change | Savings | Effort | Risk |
|--------|---------|--------|------|
| **A: Disable NAT in pilot light** | ~$65/month | 1 line change | Low |
| B1: Stop RDS manually | ~$14/month | Manual every 7 days | Medium |
| B2: Destroy RDS via Terraform | ~$16/month | Module refactoring | Medium |
| B3: Keep RDS running | $0 | None | None |

**Recommended approach:** Implement Option A (NAT Gateway) today. It's a 1-line change with ~$65/month savings. For RDS, discuss whether the $16/month is worth the complexity of stopping/destroying.

### Target Cost After Changes

| Scenario | Monthly Cost |
|----------|-------------|
| Current pilot light | ~$50-60 |
| After Option A (no NAT) | ~$17 |
| After A + B2 (no NAT, no RDS) | ~$2-3 |

### Implementation Plan

1. Create Linear issue for NAT Gateway cost optimization
2. Branch from main, make the 1-line change
3. Run `terraform plan` to verify only NAT resources affected
4. Apply and verify RDS still accessible
5. Update `dev-activate.sh` / `dev-deactivate.sh` if needed
6. Update cost documentation
7. PR, review, merge

**Estimated time:** 1-2 hours (including testing)

---

## Session Timeline

| Time | Activity |
|------|----------|
| Start | Review agenda, align on priorities |
| Block 1 | TT-104: Documentation updates |
| Block 2 | Cost reduction: NAT Gateway optimization |
| Block 3 | (If time) RDS decision and implementation |
| End | Update Linear, commit, push |
