# Disaster Recovery Strategy

**Project:** DavidShaevel.com Platform
**Primary Region:** us-east-1 (N. Virginia)
**DR Region:** us-west-2 (Oregon)
**Strategy:** Pilot Light
**Created:** January 9, 2026

---

## Executive Summary

This document outlines the disaster recovery (DR) strategy for the davidshaevel.com platform. We have selected the **Pilot Light** strategy as it provides the best balance of cost efficiency and acceptable recovery time for a portfolio/demonstration platform.

---

## DR Strategy Options Comparison

### 1. Pilot Light (Selected)

**Concept:** Keep only the essential "spark" needed to quickly provision a full environment - like a pilot light on a gas furnace that can ignite the main burner when needed.

```
┌─────────────────────────────────────────────────────────────┐
│                    PILOT LIGHT                              │
│                                                             │
│  Always Running:           Deploy On-Demand:                │
│  ┌─────────────────┐      ┌─────────────────┐              │
│  │ ECR Replication │      │ VPC/Networking  │              │
│  │ RDS Snapshots   │      │ NAT Gateway     │              │
│  │ Terraform Code  │      │ ALB             │              │
│  │ S3 State        │      │ ECS Services    │              │
│  └─────────────────┘      │ RDS Instance    │              │
│        ~$15-20/mo         └─────────────────┘              │
│                              (terraform apply)              │
└─────────────────────────────────────────────────────────────┘
```

| Metric | Value |
|--------|-------|
| Additional Monthly Cost | ~$15-20 |
| RTO (Recovery Time Objective) | 2-4 hours |
| RPO (Recovery Point Objective) | < 1 hour (snapshot frequency) |
| Automation Level | Semi-automated (requires terraform apply) |

**What's Always Running:**
- ECR cross-region replication (images synced automatically)
- Automated RDS snapshot copy to us-west-2 (hourly)
- Terraform state in S3 (ready to deploy)
- KMS key in us-west-2 for encryption

**What's Deployed On-Demand:**
- VPC and networking infrastructure
- NAT Gateway
- Application Load Balancer
- ECS Fargate services (frontend, backend)
- RDS instance (restored from snapshot)
- Observability stack (Prometheus, Grafana)

---

### 2. Warm Standby

**Concept:** Run a scaled-down but fully functional copy of the production environment in the DR region.

```
┌─────────────────────────────────────────────────────────────┐
│                    WARM STANDBY                             │
│                                                             │
│  Always Running (Scaled Down):                              │
│  ┌─────────────────────────────────────────────┐           │
│  │ VPC + Networking + NAT Gateway              │           │
│  │ ALB (active, minimal traffic)               │           │
│  │ ECS Services (1 task each vs 2 in prod)     │           │
│  │ RDS Read Replica (real-time replication)    │           │
│  │ ECR Replication                             │           │
│  └─────────────────────────────────────────────┘           │
│                    ~$80-100/mo                              │
└─────────────────────────────────────────────────────────────┘
```

| Metric | Value |
|--------|-------|
| Additional Monthly Cost | ~$80-100 |
| RTO (Recovery Time Objective) | < 1 hour |
| RPO (Recovery Point Objective) | < 5 minutes (real-time replication) |
| Automation Level | Highly automated (scale up + DNS switch) |

**Advantages:**
- Fast recovery (just scale up and switch DNS)
- Near-zero data loss with RDS read replica
- Infrastructure already validated and running

**Disadvantages:**
- Higher ongoing cost
- Paying for idle resources

---

### 3. Hot Standby (Active-Active)

**Concept:** Run identical production environments in both regions simultaneously, with traffic distributed between them.

```
┌─────────────────────────────────────────────────────────────┐
│                    HOT STANDBY                              │
│                                                             │
│  ┌──────────────┐              ┌──────────────┐            │
│  │  us-east-1   │◄── 50% ──►  │  us-west-2   │            │
│  │  (Primary)   │   traffic   │  (Secondary) │            │
│  │  Full Stack  │              │  Full Stack  │            │
│  └──────────────┘              └──────────────┘            │
│       ~$118/mo        +            ~$118/mo                │
│                    = ~$236/mo total                        │
└─────────────────────────────────────────────────────────────┘
```

| Metric | Value |
|--------|-------|
| Additional Monthly Cost | ~$118 (doubles infrastructure) |
| RTO (Recovery Time Objective) | Minutes (automatic) |
| RPO (Recovery Point Objective) | Zero (synchronous or near-sync) |
| Automation Level | Fully automated |

**Advantages:**
- Near-instant failover
- No data loss
- Load distribution improves performance

**Disadvantages:**
- Doubles infrastructure cost
- Complex data synchronization
- Overkill for most applications

---

### 4. Backup & Restore (Cheapest)

**Concept:** Rely solely on backups with no DR infrastructure pre-provisioned.

| Metric | Value |
|--------|-------|
| Additional Monthly Cost | ~$3-5 (snapshot storage only) |
| RTO (Recovery Time Objective) | 4-8+ hours |
| RPO (Recovery Point Objective) | Up to 24 hours |
| Automation Level | Manual |

**Not recommended** - Too slow for any production use case.

---

## Selected Strategy: Pilot Light

### Why Pilot Light?

For the davidshaevel.com platform (a portfolio/demonstration project):

1. **Cost-Effective:** ~$15-20/month vs ~$80-100/month for warm standby
2. **Acceptable RTO:** 2-4 hours is acceptable for a non-revenue-generating site
3. **Portfolio Value:** Demonstrates DR planning and multi-region architecture
4. **Learning Opportunity:** Manual failover process provides hands-on experience

### Pilot Light Components

#### Always Running (us-west-2)

| Component | Purpose | Cost |
|-----------|---------|------|
| ECR Replication | Container images available in DR | ~$2/mo |
| RDS Snapshot Copy | Hourly automated snapshots to DR | ~$3/mo |
| KMS Key | Encryption for RDS snapshots | ~$1/mo |
| S3 Terraform State | DR environment state | ~$0.10/mo |
| **Total** | | **~$15-20/mo** |

#### Deploy On-Demand (terraform apply)

| Component | Deploy Time | Notes |
|-----------|-------------|-------|
| VPC + Subnets | ~2 minutes | 6 subnets across 2 AZs |
| NAT Gateway | ~2 minutes | Single NAT for cost savings |
| Security Groups | ~1 minute | Mirror us-east-1 rules |
| ALB + Target Groups | ~3 minutes | HTTPS with ACM cert |
| ECS Cluster + Services | ~5 minutes | Frontend + Backend |
| RDS (from snapshot) | ~15-20 minutes | Longest component |
| **Total** | **~30-45 minutes** | |

---

## Recovery Procedures

### Failover Procedure (Primary → DR)

```bash
# 1. Confirm primary region is down
curl -s https://davidshaevel.com/api/health || echo "Primary DOWN"

# 2. Deploy DR infrastructure
cd terraform/environments/dr
terraform init
terraform apply -auto-approve

# 3. Verify DR services are healthy
./scripts/dr-validation.sh

# 4. Update DNS (Cloudflare)
# Point davidshaevel.com to DR CloudFront/ALB

# 5. Invalidate CloudFront cache (if using CloudFront)
aws cloudfront create-invalidation --distribution-id <DR-DIST-ID> --paths "/*"
```

### Failback Procedure (DR → Primary)

```bash
# 1. Confirm primary region is restored
aws ec2 describe-availability-zones --region us-east-1

# 2. Sync database changes (if any writes occurred in DR)
# Export data from DR RDS, import to primary

# 3. Verify primary services
curl -s https://<primary-alb>/api/health

# 4. Update DNS back to primary
# Point davidshaevel.com to primary CloudFront/ALB

# 5. (Optional) Destroy DR infrastructure to save costs
cd terraform/environments/dr
terraform destroy -auto-approve
```

---

## RPO and RTO Analysis

### Recovery Point Objective (RPO)

**Target:** < 1 hour
**Achieved:** ~1 hour (based on hourly snapshot frequency)

```
Timeline:
├─────────────────────────────────────────────────────────────┤
0:00                                                      1:00
│                                                            │
│  ◄─────── Snapshot Interval (1 hour) ───────►            │
│                                                            │
│  Disaster occurs here ──►  ✗                               │
│                            │                               │
│  Data loss window ─────────┤                               │
│  (up to 1 hour)            │                               │
└────────────────────────────┴───────────────────────────────┘
```

**To reduce RPO:** Increase snapshot frequency or upgrade to Warm Standby with RDS read replica.

### Recovery Time Objective (RTO)

**Target:** < 4 hours
**Achieved:** ~2-4 hours (including detection, decision, and deployment)

```
Timeline:
├─────────────────────────────────────────────────────────────┤
0:00           0:15         0:45              2:00        4:00
│               │             │                 │            │
│ Disaster ──►  │             │                 │            │
│               │             │                 │            │
│ Detection ────┤             │                 │            │
│ (~15 min)     │             │                 │            │
│               │ Terraform ──┤                 │            │
│               │ Deploy      │                 │            │
│               │ (~30 min)   │                 │            │
│               │             │ RDS Restore ────┤            │
│               │             │ (~60 min)       │            │
│               │             │                 │ DNS + ─────┤
│               │             │                 │ Validation │
│               │             │                 │ (~30 min)  │
└───────────────┴─────────────┴─────────────────┴────────────┘
```

---

## Cost Summary

### Current (Primary Only)
- **Monthly:** ~$118-125

### With Pilot Light DR
- **Primary:** ~$118-125
- **DR (always-on):** ~$15-20
- **Total:** ~$135-145/month

### During DR Activation
- **DR (fully deployed):** ~$118/month
- Note: Destroy DR after failback to return to pilot light costs

---

## Testing Schedule

| Test Type | Frequency | Description |
|-----------|-----------|-------------|
| Snapshot Verification | Weekly | Verify snapshots exist and are restorable |
| Terraform Validation | Monthly | `terraform plan` on DR environment |
| Tabletop Exercise | Quarterly | Walk through failover procedure |
| Full DR Test | Annually | Complete failover and failback |

---

## Related Documentation

- [DR Architecture Diagram](./dr-architecture.md)
- [Failover Runbook](./failover-runbook.md)
- [Failback Runbook](./failback-runbook.md)
- [DR Testing Procedures](./dr-testing-procedures.md)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-09 | David Shaevel | Initial document |
