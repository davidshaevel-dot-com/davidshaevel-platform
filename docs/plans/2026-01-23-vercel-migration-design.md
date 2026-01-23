# Vercel Migration & AWS Cost Optimization Design

**Date:** January 23, 2026
**Status:** Approved
**Author:** David Shaevel (with Claude)

## Overview

Migrate the davidshaevel-platform from AWS ECS to Vercel as the primary hosting platform, while maintaining AWS infrastructure in a "pilot light" mode for skills practice and DR capabilities.

### Goals

1. Reduce monthly AWS bill from ~$50-60/month to ~$2-3/month
2. Keep AWS ECS environment readily available for skills practice
3. Maintain DR capabilities in us-west-2
4. Enable quick activation/deactivation of AWS infrastructure

## Architecture

### Three-Environment Model

```
                              ┌─────────────────────┐
                              │   Cloudflare DNS    │
                              │  davidshaevel.com   │
                              └─────────┬───────────┘
                                        │
              ┌─────────────────────────┼─────────────────────────┐
              │                         │                         │
              ▼                         ▼                         ▼
     ┌────────────────┐       ┌────────────────┐       ┌────────────────┐
     │    VERCEL      │       │   AWS DEV      │       │    AWS DR      │
     │   (Primary)    │       │  us-east-1     │       │   us-west-2    │
     │                │       │                │       │                │
     │  ┌──────────┐  │       │  ┌──────────┐  │       │  ┌──────────┐  │
     │  │ Frontend │  │       │  │ CloudFront│ │       │  │   ALB    │  │
     │  │ Backend  │  │       │  │    ALB   │  │       │  │   ECS    │  │
     │  └────┬─────┘  │       │  │    ECS   │  │       │  └────┬─────┘  │
     │       │        │       │  └────┬─────┘  │       │       │        │
     │  ┌────▼─────┐  │       │  ┌────▼─────┐  │       │  ┌────▼─────┐  │
     │  │   Neon   │  │       │  │   RDS    │  │       │  │   RDS    │  │
     │  │ Postgres │  │       │  │ Postgres │  │       │  │ Postgres │  │
     │  └──────────┘  │       │  └──────────┘  │       │  └──────────┘  │
     └────────────────┘       └────────────────┘       └────────────────┘
```

### Operating Modes

| Mode | DNS Points To | Dev Status | DR Status | Monthly Cost |
|------|---------------|------------|-----------|--------------|
| Normal | Vercel | Pilot Light | Pilot Light | ~$2-3 |
| AWS Practice | CloudFront | Full Mode | Pilot Light | ~$45-55 |
| DR Failover | DR ALB | Down/Pilot | Full Mode | ~$45-55 |

### Pilot Light Components (Always On)

**AWS Dev (us-east-1):**
- ECR repositories (images updated by CI/CD)
- S3 buckets (Terraform state, configs)
- CloudWatch log groups
- CloudFront distribution (disabled)

**AWS DR (us-west-2):**
- ECR repositories (cross-region replication)
- RDS snapshots (cross-region copy)
- KMS encryption key
- Snapshot copy Lambda + EventBridge

## Data Synchronization

```
                         ┌─────────────────────┐
                         │        NEON         │
                         │   (Vercel Postgres) │
                         └──────────┬──────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               │               ▲
             ① ACTIVATE            │          ⑥ SYNC BACK
             (on-demand)           │          (on-demand)
             pg_dump → S3          │          S3 → pg_restore
                    │               │               │
                    ▼               │               │
               ┌────────┐          │          ┌────────┐
               │   S3   │          │          │   S3   │
               │ (dump) │          │          │ (dump) │
               └────┬───┘          │          └────▲───┘
                    │               │               │
             ② RESTORE             │          ⑤ EXPORT
             (on-demand)           │          (on-demand)
                    │               │               │
                    ▼               │               │
               ┌─────────────────────────────────────┐
               │              AWS DEV                 │
               │           RDS Postgres               │
               └──────────────────┬──────────────────┘
                                  │
                           ③ NIGHTLY (automated)
                                  │
                                  ▼
                         ┌───────────────┐
                         │  DEV SNAPSHOT │
                         └───────┬───────┘
                                 │
                          ④ CROSS-REGION (automated)
                                 │
                                 ▼
                         ┌───────────────┐
                         │  DR SNAPSHOT  │
                         └───────────────┘
```

### Sync Scenarios

**Scenario A: Activate AWS for practice (read-only)**
1. Run: `./scripts/dev-activate.sh`
2. Practice AWS skills, view data
3. Run: `./scripts/dev-deactivate.sh`
- No sync needed (no data changes)

**Scenario B: Activate AWS, make data changes, sync back**
1. Run: `./scripts/dev-activate.sh`
2. Make database changes in AWS
3. Run: `./scripts/dev-deactivate.sh --sync-to-neon`
- Exports RDS to S3, imports to Neon, then deactivates

**Scenario C: Activate AWS, make data changes, keep both updated**
1. Run: `./scripts/dev-activate.sh`
2. Make database changes in AWS
3. Run: `./scripts/sync-rds-to-neon.sh` (while AWS still active)
4. Continue working, repeat step 3 as needed
5. Run: `./scripts/dev-deactivate.sh`

## Technology Choices

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Frontend hosting | Vercel | Free tier, excellent Next.js support |
| Backend hosting | Vercel Serverless | Free tier, same platform as frontend |
| Database (Vercel) | Neon | Serverless Postgres, generous free tier, native pg_dump/restore |
| Database (AWS) | RDS PostgreSQL | Existing infrastructure, snapshot support |
| DNS | Cloudflare | Already in use, API for automation |

## Backend Adaptation

The NestJS backend will be adapted to run on both Vercel (serverless) and AWS ECS (container):

| Component | AWS ECS | Vercel Serverless |
|-----------|---------|-------------------|
| Entry point | `src/main.ts` | `api/index.ts` |
| Core code | Same services, controllers, modules | Same |
| Database | RDS connection string | Neon connection string |
| Build | `nest build` → Docker | `nest build` → Vercel bundles |

**Changes needed:**
- Add `vercel.json` configuration
- Add `api/index.ts` serverless wrapper using `@vendia/serverless-express`
- Environment variables for Neon connection

**No changes needed:**
- All business logic, services, controllers
- TypeORM entities and repositories
- Dockerfile and ECS deployment

## Observability

- **Vercel mode:** Use Vercel's built-in analytics (sufficient for portfolio site)
- **AWS mode:** Full Prometheus + Grafana stack (existing infrastructure)
- **grafana.davidshaevel.com:** Only accessible when AWS is activated

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/dev-activate.sh` | Activate AWS dev from pilot light |
| `scripts/dev-deactivate.sh` | Deactivate AWS dev to pilot light |
| `scripts/sync-neon-to-rds.sh` | Export Neon → S3 → RDS |
| `scripts/sync-rds-to-neon.sh` | Export RDS → S3 → Neon |
| `scripts/dns-switch.sh` | Switch DNS between Vercel and AWS |

## Activation Time Estimates

**Dev Activation (~25-30 min):**
| Step | Duration |
|------|----------|
| Neon → S3 export | ~2 min |
| RDS restore from S3 | ~15-20 min |
| VPC + networking | ~3 min |
| ECS services healthy | ~5 min |
| DNS propagation | ~1-2 min |

**Dev Deactivation (~10 min):**
| Step | Duration |
|------|----------|
| Optional: RDS → Neon sync | ~5 min |
| Terraform destroy | ~5 min |
| DNS switch to Vercel | ~1 min |

## Implementation Phases

### Phase 1: Vercel Deployment (Foundation)
- Set up Neon database
- Adapt NestJS backend for Vercel serverless
- Deploy frontend and backend to Vercel
- Configure environment variables
- Test end-to-end

### Phase 2: AWS Dev Pilot Light Mode
- Add `dev_activated` variable to Terraform
- Create activation/deactivation scripts
- Create database sync scripts
- Create DNS switch script

### Phase 3: Testing & Cutover
- Test Vercel → AWS activation cycle
- Test AWS → Vercel deactivation with sync
- Test DR failover from pilot light
- Update documentation
- Production cutover
- Deactivate AWS to pilot light

## Cost Analysis

| Item | Current | After Migration |
|------|---------|-----------------|
| AWS Dev (full) | ~$50/month | $0 (deactivated) |
| AWS Dev (pilot light) | - | ~$1-2/month |
| AWS DR (pilot light) | ~$1/month | ~$1/month |
| Vercel | $0 | $0 (free tier) |
| Neon | $0 | $0 (free tier) |
| **Total** | **~$51/month** | **~$2-3/month** |

**Savings:** ~$48-49/month (~95% reduction)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Vercel cold starts | Acceptable for portfolio site; AWS available for demos |
| Neon free tier limits | Monitor usage; 0.5GB storage sufficient for portfolio |
| Data sync complexity | Automated scripts with clear documentation |
| DR activation from pilot light | Thoroughly tested; same pattern as current DR |

## Success Criteria

- [ ] Frontend and backend deployed to Vercel (free tier)
- [ ] Neon database running (free tier)
- [ ] AWS dev environment in pilot light mode
- [ ] `dev-activate.sh` successfully activates full AWS environment
- [ ] `dev-deactivate.sh` successfully returns to pilot light
- [ ] Data sync scripts work bidirectionally
- [ ] DR failover still works from pilot light mode
- [ ] Monthly AWS bill reduced to ~$2-3
