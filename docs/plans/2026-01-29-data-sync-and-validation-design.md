# Data Sync & Dev Validation Design

**Date:** January 29, 2026
**Related Issues:** TT-98, TT-99, TT-128, TT-132
**Status:** Approved

---

## Overview

Design for bidirectional database sync between Neon (Vercel) and RDS (AWS), plus a dev environment validation script.

**Components:**
- `sync-neon-to-rds.sh` - Sync Neon → RDS (TT-98)
- `sync-rds-to-neon.sh` - Sync RDS → Neon (TT-99)
- `dev-validation.sh` - Dev environment health checks (TT-132)
- Integration with `dev-activate.sh` and `dev-deactivate.sh` (TT-128)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Data Sync Architecture                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Neon (Vercel)                         RDS (AWS Dev)            │
│   ┌──────────┐                          ┌──────────┐            │
│   │ projects │                          │ projects │            │
│   └────┬─────┘                          └────┬─────┘            │
│        │                                     │                   │
│        ▼                                     ▼                   │
│   ┌─────────────────────────────────────────────────┐           │
│   │              S3: db-backups bucket              │           │
│   │  (always-on, stores dumps with timestamps)      │           │
│   │                                                 │           │
│   │  neon-dumps/2026-01-29T10-30-00.dump           │           │
│   │  rds-dumps/2026-01-29T15-45-00.dump            │           │
│   └─────────────────────────────────────────────────┘           │
│                                                                  │
│   Scripts:                                                       │
│   • sync-neon-to-rds.sh  → Called by dev-activate.sh            │
│   • sync-rds-to-neon.sh  → Called by dev-deactivate.sh          │
│   • dev-validation.sh    → Standalone health check               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Flow:**
- **Activation**: `dev-activate.sh --sync-data` → runs `sync-neon-to-rds.sh` → dumps Neon to S3 → restores to RDS → continues with Terraform
- **Deactivation**: `dev-deactivate.sh --sync-data` → runs `sync-rds-to-neon.sh` → dumps RDS to S3 → restores to Neon → continues with Terraform

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Sync strategy | Full replace (pg_dump/pg_restore) | Simple, exact replica, handles schema changes |
| Dump storage | S3 only | Audit trail, rollback capability |
| S3 bucket | New always-on bucket | Available before/after activation |
| Dump format | `pg_dump --format=custom` | Compressed, supports pg_restore |
| Retention | 30 days via lifecycle policy | Balance of audit trail vs cost |
| Integration | Optional `--sync-data` flag | Flexibility for manual control |

---

## Terraform Changes

Add to `terraform/environments/dev/main.tf` in the "Always-On Resources" section:

```hcl
# Database Backups S3 Bucket - Always on for data sync
resource "aws_s3_bucket" "db_backups" {
  bucket = "${var.project_name}-dev-db-backups"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-dev-db-backups"
    Purpose = "Database sync dumps between Neon and RDS"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  rule {
    id     = "expire-old-dumps"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

---

## Script: sync-neon-to-rds.sh (TT-98)

**Usage:**
```bash
./scripts/sync-neon-to-rds.sh [--dry-run]
```

**Prerequisites:**
- `NEON_DATABASE_URL` environment variable
- AWS CLI configured
- `psql`, `pg_dump`, `pg_restore` installed
- RDS instance must be running

**Flow:**
1. Verify prerequisites (psql, pg_dump, AWS creds, NEON_DATABASE_URL)
2. Verify RDS is available
3. Get RDS connection details from Secrets Manager
4. Dump Neon to S3: `pg_dump → s3://davidshaevel-dev-db-backups/neon-dumps/TIMESTAMP.dump`
5. Restore to RDS: stream from S3 → `pg_restore --clean --if-exists --no-owner`
6. Verify row counts match
7. Report success/failure

**Dry-run output:**
```
========================================
  DRY RUN - No changes will be made
========================================

[INFO] Would dump Neon database...
[INFO]   Source: postgresql://****@****.neon.tech/neondb
[INFO]   Rows in projects table: 5
[INFO] Would upload to S3...
[INFO]   Destination: s3://davidshaevel-dev-db-backups/neon-dumps/2026-01-29T17-30-00.dump
[INFO] Would restore to RDS...
[INFO]   Target: davidshaevel-dev-db.*****.us-east-1.rds.amazonaws.com
[INFO]   Current rows in RDS projects table: 3

Dry run complete. Run without --dry-run to sync.
```

---

## Script: sync-rds-to-neon.sh (TT-99)

**Usage:**
```bash
./scripts/sync-rds-to-neon.sh [--dry-run]
```

**Prerequisites:**
- `NEON_DATABASE_URL` environment variable
- AWS CLI configured
- `psql`, `pg_dump`, `pg_restore` installed
- RDS instance must be running

**Flow:**
1. Verify prerequisites (psql, pg_dump, AWS creds, NEON_DATABASE_URL)
2. Verify RDS is available
3. Get RDS connection details from Secrets Manager
4. Dump RDS to S3: `pg_dump → s3://davidshaevel-dev-db-backups/rds-dumps/TIMESTAMP.dump`
5. Restore to Neon: stream from S3 → `pg_restore --clean --if-exists --no-owner`
6. Verify row counts match
7. Report success/failure

---

## Script: dev-validation.sh (TT-132)

**Usage:**
```bash
./scripts/dev-validation.sh [--verbose]
```

**Checks performed:**

| Check | Pilot Light | Active | Details |
|-------|:-----------:|:------:|---------|
| AWS credentials | ✓ | ✓ | `aws sts get-caller-identity` |
| Terraform state | ✓ | ✓ | Read `dev_activated` output |
| ECR repositories | ✓ | ✓ | 3 repos with image counts |
| S3 db-backups bucket | ✓ | ✓ | Bucket exists |
| RDS instance | ✓ | ✓ | Status = available |
| VPC & networking | ✓ | ✓ | VPC state = available |
| ECS cluster | | ✓ | Cluster exists |
| ECS services (4) | | ✓ | backend, frontend, prometheus, grafana |
| ALB health | | ✓ | `/api/health` returns 200 |
| CloudFront | | ✓ | Distribution enabled |
| Service discovery | | ✓ | Cloud Map registrations |

**Output format:**
```
========================================
  DEV ENVIRONMENT VALIDATION
  Region: us-east-1
========================================

[INFO] Checking AWS credentials...
[PASS] AWS credentials valid
[INFO] Checking Terraform state...
[PASS] Dev infrastructure is activated (full mode)
...

========================================
  VALIDATION SUMMARY
========================================
  Mode:      Full (activated)
  Passed:   12
  Warnings: 1
  Failed:   0

Dev environment is healthy
```

---

## Integration: dev-activate.sh & dev-deactivate.sh (TT-128)

**New flag for both scripts:**
```bash
--sync-data    Sync database before operation
```

**Behavior matrix:**

| Flags | Sync Scripts | Terraform |
|-------|--------------|-----------|
| `--dry-run` | Skip sync | `terraform plan` only |
| `--sync-data` | Run sync | `terraform apply` |
| `--sync-data --dry-run` | Sync with `--dry-run` | `terraform plan` only |

**dev-activate.sh changes:**
```bash
# After RDS check, before Terraform apply:
if [[ "${SYNC_DATA}" == "true" ]]; then
    log_info "Syncing data from Neon to RDS..."
    SYNC_FLAGS=()
    if [[ "${DRY_RUN}" == "true" ]]; then
        SYNC_FLAGS+=(--dry-run)
    fi
    "${SCRIPT_DIR}/sync-neon-to-rds.sh" "${SYNC_FLAGS[@]}"
fi
```

**dev-deactivate.sh changes:**
```bash
# After confirmation, before Terraform apply:
if [[ "${SYNC_DATA}" == "true" ]]; then
    log_info "Syncing data from RDS to Neon..."
    SYNC_FLAGS=()
    if [[ "${DRY_RUN}" == "true" ]]; then
        SYNC_FLAGS+=(--dry-run)
    fi
    "${SCRIPT_DIR}/sync-rds-to-neon.sh" "${SYNC_FLAGS[@]}"
fi
```

**Usage examples:**
```bash
# Activate with fresh data from Neon
./scripts/dev-activate.sh --sync-data

# Deactivate and preserve changes to Neon
./scripts/dev-deactivate.sh --sync-data --yes

# Activate without sync (use existing RDS data)
./scripts/dev-activate.sh

# Preview what sync + activation would do
./scripts/dev-activate.sh --sync-data --dry-run
```

---

## Implementation Order

1. **Terraform**: Add S3 bucket for db-backups (always-on)
2. **TT-98**: Create `sync-neon-to-rds.sh`
3. **TT-99**: Create `sync-rds-to-neon.sh`
4. **TT-132**: Create `dev-validation.sh`
5. **TT-128**: Add `--sync-data` flag to activate/deactivate scripts
6. **Testing**: Run full activation/deactivation cycle with sync

---

## Outputs to Add

```hcl
output "db_backups_bucket_name" {
  description = "Name of the S3 bucket for database backup dumps"
  value       = aws_s3_bucket.db_backups.id
}

output "db_backups_bucket_arn" {
  description = "ARN of the S3 bucket for database backup dumps"
  value       = aws_s3_bucket.db_backups.arn
}
```
