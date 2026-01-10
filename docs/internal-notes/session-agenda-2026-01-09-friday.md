# Work Session Agenda - Friday, January 9, 2026

**Project:** DavidShaevel.com Platform
**Focus:** Disaster Recovery Environment Planning and Setup
**Branch:** `tt-65-dr-environment-setup`

---

## Session Overview

Create a comprehensive disaster recovery (DR) environment in AWS us-west-2 region to complement the existing production infrastructure in us-east-1.

## Completed This Session

### Linear Project Created

**Project:** [Disaster Recovery Environment (us-west-2)](https://linear.app/davidshaevel-dot-com/project/disaster-recovery-environment-us-west-2-be642ca687a6)

**Goals:**
- RPO (Recovery Point Objective): < 5 minutes
- RTO (Recovery Time Objective): < 1 hour
- Automated failover via CloudFront + DNS health checks

### Linear Issues Created (10 Total)

| Issue | Title | Phase | Dependencies |
|-------|-------|-------|--------------|
| TT-65 | DR Terraform Environment Setup (us-west-2) | Foundation | None |
| TT-66 | DR VPC and Networking Infrastructure | Foundation | TT-65 |
| TT-67 | Cross-Region RDS Database Replication | Database | TT-66 |
| TT-68 | Cross-Region ECR Replication | Container | TT-65 |
| TT-69 | DR Compute Infrastructure (ECS + ALB) | Compute | TT-66, TT-67, TT-68 |
| TT-70 | DR Observability Stack (Prometheus + Grafana) | Observability | TT-69 |
| TT-71 | CloudFront Multi-Origin Failover Configuration | Failover | TT-69 |
| TT-72 | DNS Failover and Health Checks | Failover | TT-71 |
| TT-73 | DR Testing and Validation | Testing | All DR infra |
| TT-74 | DR Runbook and Documentation | Documentation | TT-73 |

---

## Implementation Order (Recommended)

### Phase 1: Foundation (TT-65, TT-66)
- Set up Terraform environment for DR
- Deploy VPC and networking in us-west-2
- **Estimated effort:** 2-3 hours

### Phase 2: Data Layer (TT-67, TT-68)
- Configure cross-region RDS replication
- Set up ECR cross-region replication
- **Estimated effort:** 2-3 hours

### Phase 3: Compute (TT-69, TT-70)
- Deploy ECS cluster and ALB in DR region
- Deploy observability stack (optional for warm standby)
- **Estimated effort:** 3-4 hours

### Phase 4: Failover (TT-71, TT-72)
- Configure CloudFront multi-origin failover
- Set up DNS health checks and failover
- **Estimated effort:** 2-3 hours

### Phase 5: Validation (TT-73, TT-74)
- Execute DR test scenarios
- Document runbooks and procedures
- **Estimated effort:** 3-4 hours

**Total estimated effort:** 12-17 hours

---

## Cost Analysis

### Current Infrastructure (us-east-1)
| Resource | Monthly Cost |
|----------|-------------|
| NAT Gateways (2) | ~$64 |
| ECS Fargate (6 tasks) | ~$68 |
| RDS PostgreSQL | ~$12 |
| ALB | ~$20 |
| EFS + S3 | ~$3 |
| **Total** | **~$118-125** |

### DR Infrastructure Options

#### Option A: Warm Standby (~$80-100/month additional)
- Single NAT Gateway: ~$32
- RDS Read Replica: ~$12
- ECS (2 tasks, warm): ~$17
- ALB: ~$16
- EFS: ~$2
- **Total with DR:** ~$200-225/month

#### Option B: Cold Standby (~$50-60/month additional)
- Single NAT Gateway: ~$32
- Cross-region snapshots: ~$3
- ECS (0 tasks): $0
- ALB: ~$16
- **Total with DR:** ~$170-185/month

#### Option C: Pilot Light (~$15-20/month additional)
- No NAT Gateway (deploy on demand)
- Cross-region snapshots: ~$3
- RDS snapshot restore (on-demand)
- ECR replication only: ~$2
- **Total with DR:** ~$135-145/month

**Recommended:** Option A (Warm Standby) for < 1 hour RTO

---

## Today's Remaining Work

If continuing this session:

1. **Start TT-65:** Create `terraform/environments/dr/` directory structure
2. **Configure S3 backend** for DR state management
3. **Set up AWS provider** for us-west-2 region

### Quick Start Commands

```bash
# Create DR environment directory
mkdir -p terraform/environments/dr

# Copy dev environment as template
cp terraform/environments/dev/*.tf terraform/environments/dr/

# Update region and backend configuration
# Edit terraform/environments/dr/main.tf
# Edit terraform/environments/dr/terraform.tfvars
```

---

## Architecture Reference

### Current State (us-east-1)

```
┌─────────────────────────────────────────────────────────────┐
│                     Cloudflare DNS                          │
│                   davidshaevel.com                          │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                    CloudFront CDN                           │
│              (Single Origin: us-east-1)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                  ALB (us-east-1)                            │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
   │Frontend │     │ Backend │     │Grafana  │
   │ (ECS)   │     │ (ECS)   │     │ (ECS)   │
   └─────────┘     └────┬────┘     └─────────┘
                        │
                   ┌────▼────┐
                   │   RDS   │
                   │PostgreSQL│
                   └─────────┘
```

### Target State (Multi-Region)

```
┌─────────────────────────────────────────────────────────────┐
│                     Cloudflare DNS                          │
│          (Health Checks + Failover Records)                 │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                    CloudFront CDN                           │
│          (Origin Group: Primary + Failover)                 │
└────────┬───────────────────────────────────┬────────────────┘
         │                                   │
         │ Primary                           │ Failover
         │                                   │
┌────────▼────────┐                 ┌────────▼────────┐
│  ALB us-east-1  │                 │  ALB us-west-2  │
└────────┬────────┘                 └────────┬────────┘
         │                                   │
    ┌────┴────┐                         ┌────┴────┐
    │ECS/RDS  │ ◄─── Replication ────► │ECS/RDS  │
    │us-east-1│      (Cross-Region)    │us-west-2│
    └─────────┘                         └─────────┘
```

---

## Next Session Preview

Continue with TT-65 implementation:
- Create DR environment Terraform files
- Configure backend state for DR
- Validate Terraform configuration

---

**Session Created:** January 9, 2026
**Last Updated:** January 9, 2026
