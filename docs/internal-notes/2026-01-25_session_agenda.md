# Work Session Agenda - Sunday, January 25, 2026

**Project:** DavidShaevel.com Platform
**Focus:** Vercel Migration - Phase 2: AWS Pilot Light Mode
**Branch:** `vercel-migration`

---

## Session Overview

Phase 1 is complete (Vercel serving davidshaevel.com). Phase 2 focuses on converting the AWS dev environment to a pilot light mode that can be activated on-demand for skills practice and DR.

---

## Current State

- davidshaevel.com → Vercel (frontend + backend)
- Database → Neon PostgreSQL (free tier)
- AWS → Running but not receiving traffic
- DNS → Managed via `scripts/vercel-dns-switch.sh`

---

## Today's Tasks

### 1. TT-94: End-to-End Testing of Vercel Deployment

**Verify all functionality works on the live domain:**

- [ ] Homepage loads correctly
- [ ] All pages render (About, Projects, Contact)
- [ ] Contact form submits and sends email
- [ ] API health endpoint returns 200
- [ ] API projects endpoint returns data
- [ ] No console errors in browser
- [ ] Mobile responsive design works
- [ ] Performance acceptable (< 3s initial load)

### 2. TT-95: Add dev_activated Variable to Terraform

**Make AWS dev infrastructure conditional:**

1. Add `dev_activated` variable to `terraform/environments/dev/variables.tf`
2. Make ECS services conditional on `dev_activated`
3. Make NAT Gateways conditional (biggest cost saver: ~$68/mo)
4. Make ALB conditional
5. Keep always-on: ECR repos, S3 buckets, IAM roles
6. Keep RDS for now (can be deactivated later)

**Pattern Reference:** Follow the existing `dr_activated` pattern from DR environment

### 3. TT-96: Create dev-activate.sh Script

**Script to spin up AWS dev from pilot light:**

```bash
./scripts/dev-activate.sh [--dry-run]
```

Flow:
1. Verify AWS credentials
2. Sync Neon → RDS (if needed)
3. Run `terraform apply -var="dev_activated=true"`
4. Wait for ECS services to be healthy
5. Switch DNS to CloudFront
6. Display success message with URLs

### 4. TT-97: Create dev-deactivate.sh Script

**Script to return to pilot light:**

```bash
./scripts/dev-deactivate.sh [--dry-run] [--sync-to-neon]
```

Flow:
1. Optionally sync RDS → Neon
2. Switch DNS to Vercel
3. Run `terraform apply -var="dev_activated=false"`
4. Display cost savings

---

## Quick Reference

### Vercel
- Dashboard: https://vercel.com/davidshaevel-dot-com
- Frontend: https://davidshaevel-frontend.vercel.app
- Backend: https://davidshaevel-backend.vercel.app
- Live: https://davidshaevel.com

### AWS (currently idle)
- CloudFront: `dbaz91yl33r82.cloudfront.net`
- ALB: `dev-davidshaevel-alb-85034469.us-east-1.elb.amazonaws.com`

### Git Worktree
```bash
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/vercel-migration
```

---

## Success Criteria for Today

- [ ] All Vercel endpoints tested end-to-end
- [ ] `dev_activated` variable added to Terraform
- [ ] Activation/deactivation scripts created
- [ ] At least one activation/deactivation cycle tested

---

**Session Created:** January 24, 2026
