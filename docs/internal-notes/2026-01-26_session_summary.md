# Work Session Summary - Monday, January 26, 2026

**Project:** DavidShaevel.com Platform
**Focus:** AWS Pilot Light Mode Implementation (TT-95, TT-96, TT-97)
**Branch:** `claude/tt-95-pilot-light-mode` (merged to `main`)

---

## Session Overview

Completed Phase 2 of the Vercel Migration project by implementing AWS Pilot Light Mode. This adds the ability to toggle the dev environment between active (full infrastructure) and pilot light (minimal cost) modes using a `dev_activated` Terraform variable and supporting scripts.

---

## Completed Today

### TT-95: Add dev_activated variable to dev Terraform (DONE)

- Added `dev_activated` boolean variable with default `true`
- Made the following modules conditional with `count = var.dev_activated ? 1 : 0`:
  - `module.compute` - ECS Cluster, Fargate services, ALB
  - `module.cdn` - CloudFront distribution
  - `module.cicd_iam` - GitHub Actions deployment permissions
  - `module.observability` - Prometheus, Grafana, EFS
  - `module.service_discovery` - Cloud Map namespace and services
- Kept always-on (not conditional):
  - `module.networking` - VPC, subnets, NAT Gateways (due to RDS dependencies)
  - `module.database` - RDS PostgreSQL
- Extracted ECR repositories as top-level always-on resources with `moved {}` blocks for state migration
- Added conditional outputs for all affected modules
- Applied Terraform to complete state migrations (0 added, 3 changed, 0 destroyed)

### TT-96: Create dev-activate.sh script (DONE)

Created `scripts/dev-activate.sh` with:
- AWS credentials verification
- Dynamic ECR registry from `aws sts get-caller-identity`
- ECR image availability check (backend, frontend)
- RDS availability check
- Terraform apply with `dev_activated=true`
- `--dry-run` and `--yes` flags
- Configurable via `PROJECT_NAME` and `AWS_REGION` environment variables

### TT-97: Create dev-deactivate.sh script (DONE)

Created `scripts/dev-deactivate.sh` with:
- AWS credentials verification
- **Automated Vercel production check** - curl check for `server: Vercel` header
- Deactivation plan display (resources to destroy/preserve)
- Terraform apply with `dev_activated=false`
- `--dry-run` and `--yes` flags
- Configurable via `PROJECT_NAME` and `AWS_REGION` environment variables

### Code Review (2 Rounds with Gemini)

**Round 1 (8 issues addressed):**
- Dynamic AWS account ID for ECR registry
- Configurable ECR repo names via `PROJECT_NAME`
- Configurable RDS identifier
- `AWS_REGION` environment variable support
- Local variables for default container ports

**Round 2 (6 issues addressed):**
- Automated Vercel production check (HIGH priority)
- ECR image query filters for tagged images only
- Documentation fixes in CLAUDE.md
- Detailed port sync comments in Terraform

### Follow-up Issues Created

| Issue | Title | Priority |
|-------|-------|----------|
| TT-127 | Add Cloudflare DNS automation to pilot light scripts | Medium |
| TT-128 | Add Neon/RDS data sync integration to pilot light scripts | Low |
| TT-129 | Add ECS health check and CloudFront cache invalidation | Low |

---

## Pull Request

**PR #84:** feat: Add AWS Pilot Light mode for dev environment
- Merged via Squash and Merge
- Commit: `81a03b1`

---

## Commits (in PR #84)

| Hash | Message |
|------|---------|
| `f1c8e20` | feat(pilot-light): add dev_activated variable to dev environment |
| `8212e8c` | feat(pilot-light): make modules conditional on dev_activated |
| `31048c8` | feat(pilot-light): add activation and deactivation scripts |
| `caa63c4` | feat(pilot-light): update outputs for conditional modules |
| `f9cff31` | feat(pilot-light): extract ECR repos as always-on resources |
| `8f64f2c` | fix(pilot-light): address Gemini code review feedback |
| `abb9664` | fix(pilot-light): address second round of Gemini code review |

---

## Files Created/Modified

### New Files
- `scripts/dev-activate.sh` - Activate dev environment from pilot light mode
- `scripts/dev-deactivate.sh` - Deactivate dev environment to pilot light mode

### Modified Files
- `terraform/environments/dev/variables.tf` - Added `dev_activated` variable
- `terraform/environments/dev/main.tf` - Conditional modules, ECR extraction, state moves
- `terraform/environments/dev/outputs.tf` - Conditional output handling
- `CLAUDE.md` - Updated scope guidelines

---

## Cost Analysis

### Always-On Resources (Pilot Light Mode)

| Resource Type | Monthly Cost |
|---------------|--------------|
| VPC & Networking (incl. 2x NAT Gateways) | ~$65 |
| RDS PostgreSQL (db.t3.micro) | ~$15 |
| ECR Repositories (storage only) | ~$0 |
| S3 Buckets | ~$1 |
| CloudWatch Log Groups | ~$0.50 |
| **Subtotal** | **~$81.50/mo** |

### Conditional Resources (Destroyed in Pilot Light)

| Resource Type | Monthly Cost |
|---------------|--------------|
| ECS Cluster & Services (4 tasks) | ~$30 |
| Application Load Balancer | ~$18 |
| CloudFront Distribution | ~$5 |
| Observability Stack (EFS, configs) | ~$3 |
| Service Discovery | ~$1 |
| **Subtotal** | **~$57/mo** |

### Cost Summary

| Mode | Monthly Cost | Savings |
|------|--------------|---------|
| **Active** (`dev_activated=true`) | ~$138/mo | - |
| **Pilot Light** (`dev_activated=false`) | ~$81/mo | ~$57/mo (41%) |

**Note:** NAT Gateways (~$65/mo) remain always-on due to RDS dependencies. Future optimization could reduce pilot light cost to ~$16/mo if networking is made conditional.

---

## Issues Encountered & Resolved

| Issue | Resolution |
|-------|------------|
| `Invalid index` errors when `dev_activated=false` | Added conditional guards to all cross-module references |
| ECR repos marked for destruction | Extracted to top-level resources with `moved {}` blocks |
| Terraform state lock from previous session | Force unlocked with `terraform force-unlock` |
| AWS SSO credentials expired | Refreshed with `aws sso login` |
| Networking module has RDS dependency | Kept networking always-on; documented NAT cost impact |

---

## Current State

- **Pilot Light Mode:** Fully implemented and tested
- **Dev Environment:** Currently ACTIVE (`dev_activated=true`)
- **Terraform State:** Synchronized, no drift
- **Linear Issues:** TT-95, TT-96, TT-97 marked DONE
- **Follow-up Issues:** TT-127, TT-128, TT-129 in Backlog

---

## What Remains for Full Pilot Light

To achieve minimum cost (~$16/mo), future work could:
1. Make networking module conditional (requires RDS networking refactor)
2. Add RDS stop/start automation
3. Implement DNS automation (TT-127)
4. Implement data sync (TT-128)

---

**Session Created:** January 26, 2026
**Last Updated:** January 26, 2026
