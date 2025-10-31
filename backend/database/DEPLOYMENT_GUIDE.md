# Database Deployment Guide for New Environments

This guide provides step-by-step instructions for deploying the database schema to new environments (dev, staging, production).

## Pre-Deployment Checklist

Before deploying to any environment:

- [ ] Review all migration files in `migrations/` directory
- [ ] Verify migration numbering is sequential (001, 002, etc.)
- [ ] Test migrations in local development environment
- [ ] Backup existing database (if applicable)
- [ ] Schedule maintenance window (production only)
- [ ] Notify team of deployment plans

## Deployment Options

### Option A: Automatic Schema Creation (Development Only)

**Use Case:** Initial deployment to development environment
**Safety Level:** ⚠️ Development only - NOT for production

**Steps:**

1. **Enable TypeORM Synchronize**
   - Set `TYPEORM_SYNCHRONIZE=true` in ECS task definition
   - This is already configured in `terraform/modules/compute/main.tf`

2. **Deploy Backend**
   ```bash
   # Build and push Docker image
   cd backend
   docker build -t davidshaevel/backend:$(git rev-parse --short HEAD) .

   # Push to ECR
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
   docker tag davidshaevel/backend:$(git rev-parse --short HEAD) <ecr-uri>:$(git rev-parse --short HEAD)
   docker push <ecr-uri>:$(git rev-parse --short HEAD)

   # Update Terraform and deploy
   cd ../terraform/environments/dev
   # Update terraform.tfvars with new image tag
   terraform apply
   ```

3. **Verify Schema Creation**
   ```bash
   # Wait for backend to start (30-60 seconds)
   # Test API endpoint
   curl https://davidshaevel.com/api/projects
   # Should return: [] (empty array, not 500 error)
   ```

4. **⚠️ IMPORTANT: Disable Synchronize After Initial Deployment**
   ```bash
   # Edit terraform/modules/compute/main.tf
   # Comment out or remove: TYPEORM_SYNCHRONIZE = "true"
   # Or set to: TYPEORM_SYNCHRONIZE = "false"

   # Redeploy
   terraform apply
   ```

**Pros:**
- Fast initial deployment
- No manual migration running required
- Schema matches TypeORM entities exactly

**Cons:**
- Not safe for production (can cause data loss)
- Limited control over schema changes
- No migration history tracking

---

### Option B: Manual Migration (Production Recommended)

**Use Case:** Production deployments, staging, or any environment with existing data
**Safety Level:** ✅ Production-safe with proper testing

#### Prerequisites

- Database is accessible (via VPC, bastion host, or VPN)
- You have database credentials from AWS Secrets Manager
- Docker is installed on your local machine or bastion host

#### Step-by-Step Instructions

**1. Get Database Connection Details**

```bash
# From terraform/environments/<env> directory
cd terraform/environments/dev  # or prod

# Get database endpoint
DB_ENDPOINT=$(terraform output -raw database_endpoint)
DB_NAME=$(terraform output -raw database_name)
DB_SECRET_ARN=$(terraform output -raw database_secret_arn)

# Get credentials from Secrets Manager
DB_USER=$(aws secretsmanager get-secret-value \
  --secret-id "${DB_SECRET_ARN}" \
  --query 'SecretString' \
  --output text | jq -r '.username')

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "${DB_SECRET_ARN}" \
  --query 'SecretString' \
  --output text | jq -r '.password')

echo "Database: ${DB_NAME}@${DB_ENDPOINT}"
echo "User: ${DB_USER}"
```

**2. Verify Database Connectivity**

```bash
# Test connection (from within VPC or via bastion)
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
  -c "SELECT version();"
```

**3. Check Current Schema State**

```bash
# List all tables
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
  -c "\dt"

# If projects table exists, check structure
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
  -c "\d projects"
```

**4. Apply Migrations**

```bash
# Navigate to backend database directory
cd /path/to/davidshaevel-platform/backend/database

# Apply migrations in order
for migration in migrations/*.sql; do
  echo "=========================================="
  echo "Applying migration: $migration"
  echo "=========================================="

  docker run --rm -i postgres:15 psql \
    "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
    < "$migration"

  if [ $? -eq 0 ]; then
    echo "✅ Migration completed successfully"
  else
    echo "❌ Migration failed!"
    exit 1
  fi

  echo ""
done
```

**5. Verify Schema and Data**

```bash
# Verify projects table structure
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
  -c "\d projects"

# Check data
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
  -c "SELECT id, title, array_length(technologies, 1) as tech_count FROM projects;"
```

**6. Test Application API**

```bash
# Test health check
curl https://your-domain.com/api/health

# Test projects endpoint
curl https://your-domain.com/api/projects

# Test POST (create)
curl -X POST https://your-domain.com/api/projects \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Test project","technologies":["Test"]}'
```

**7. Update Migration History**

Update `backend/database/README.md` Migration History table:

```markdown
| Migration | Date | Description | Applied To |
|-----------|------|-------------|------------|
| 001 | 2025-10-31 | Create projects table | dev, prod |
| 002 | 2025-10-31 | Seed initial project | dev, prod |
```

---

## Environment-Specific Guides

### Dev Environment

**Database:**
- RDS Endpoint: `davidshaevel-dev-db.c8ra24guey7i.us-east-1.rds.amazonaws.com`
- Database Name: `davidshaevel`
- Credentials: AWS Secrets Manager (`rds!db-*`)

**Access:**
- From ECS tasks (within VPC)
- Not directly accessible from internet

**Deployment Method:**
- Use Option A (TypeORM Synchronize) for initial setup
- Use Option B (Manual Migration) for subsequent changes

**Status:** ✅ Deployed (2025-10-31)

### Production Environment (Future)

**Database:**
- RDS Endpoint: TBD
- Database Name: `davidshaevel`
- Credentials: AWS Secrets Manager

**Access:**
- From ECS tasks only (within VPC)
- Via bastion host for maintenance

**Deployment Method:**
- **ALWAYS use Option B (Manual Migration)**
- **NEVER use TypeORM Synchronize in production**

---

## Troubleshooting

### Issue: Can't Connect to Database

**Symptoms:**
- `connection refused` error
- `timeout` error

**Solutions:**
1. Verify you're connecting from within VPC (ECS task, bastion, VPN)
2. Check security group rules allow PostgreSQL (port 5432)
3. Verify RDS endpoint is correct
4. Check database is running: `aws rds describe-db-instances`

### Issue: Migration Fails with "relation already exists"

**Symptoms:**
- `ERROR: relation "projects" already exists`

**Solutions:**
1. This is expected if migrations were already run
2. Migrations use `IF NOT EXISTS` - they're idempotent
3. Safe to re-run migrations

### Issue: TypeORM Synchronize Not Creating Schema

**Symptoms:**
- API returns 500 error
- Logs show "relation does not exist"

**Solutions:**
1. Verify `TYPEORM_SYNCHRONIZE=true` in ECS task definition
2. Check logs for TypeORM initialization messages
3. Verify backend image includes updated code
4. Force new deployment: `aws ecs update-service --force-new-deployment`

### Issue: Schema Exists but API Still Fails

**Symptoms:**
- Table exists in database
- API returns 500 error

**Solutions:**
1. Check CloudWatch logs for specific errors
2. Verify database credentials are correct
3. Check SSL mode is set correctly (`rejectUnauthorized: false` for RDS)
4. Verify network connectivity from ECS tasks to RDS

---

## Rollback Procedures

### If Migration Fails

1. **Stop application traffic**
   ```bash
   aws ecs update-service --cluster <cluster> --service <service> --desired-count 0
   ```

2. **Restore database from backup**
   ```bash
   # For RDS
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier <new-id> \
     --db-snapshot-identifier <snapshot-id>
   ```

3. **Investigate and fix migration**
   - Review migration SQL
   - Test in development environment
   - Create corrected migration

4. **Re-apply migrations**
   - Follow Option B steps above

5. **Restore application**
   ```bash
   aws ecs update-service --cluster <cluster> --service <service> --desired-count 2
   ```

### If TypeORM Synchronize Causes Issues

1. **Disable synchronize immediately**
   ```bash
   # Remove or comment out TYPEORM_SYNCHRONIZE from task definition
   terraform apply
   ```

2. **Restore from backup if data was lost**

3. **Switch to manual migrations** (Option B)

---

## Best Practices

### Development
- ✅ Use TypeORM Synchronize for initial schema creation
- ✅ Disable synchronize after initial deployment
- ✅ Test migrations in dev before staging/prod
- ✅ Keep migration history updated

### Production
- ✅ **ALWAYS** use manual migrations
- ✅ **NEVER** use TypeORM Synchronize
- ✅ Test in staging first
- ✅ Schedule maintenance windows
- ✅ Create database backups before migrations
- ✅ Have rollback plan ready
- ✅ Monitor application after deployment

### General
- ✅ Keep migrations small and focused
- ✅ Use idempotent SQL (IF NOT EXISTS, IF EXISTS)
- ✅ Document all migrations
- ✅ Commit migration files to git
- ✅ Never modify existing migrations that have been applied
- ✅ Create new migrations to fix issues

---

## Quick Reference

### Run All Migrations (One Command)

```bash
# Set variables
export DB_ENDPOINT="your-db-endpoint"
export DB_NAME="davidshaevel"
export DB_USER="dbadmin"
export DB_PASSWORD="your-password"

# Run migrations
cd backend/database
for f in migrations/*.sql; do
  echo "Applying $f..."
  docker run --rm -i postgres:15 psql \
    "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
    < "$f"
done
```

### Verify Schema

```bash
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
  -c "\d projects"
```

### Test API

```bash
curl https://davidshaevel.com/api/projects
```

---

**Last Updated:** 2025-10-31
**Document Version:** 1.0
**Environments Covered:** Development, Production (future)
