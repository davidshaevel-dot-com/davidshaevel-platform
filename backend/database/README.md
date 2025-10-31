# Database Migrations

This directory contains SQL migration scripts for the DavidShaevel.com platform database.

## Migration Files

Migrations are numbered sequentially and should be applied in order:

- **001_create_projects_table.sql** - Creates the `projects` table with indexes and triggers
- **002_seed_initial_project.sql** - Inserts initial project data

## Applying Migrations

### Method 1: Using Docker and psql (Recommended for local/dev)

```bash
# Set database connection details
DB_HOST="your-db-host"
DB_PORT="5432"
DB_NAME="davidshaevel"
DB_USER="dbadmin"
DB_PASSWORD="your-password"

# Apply migration using Docker
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require" \
  < migrations/001_create_projects_table.sql

docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require" \
  < migrations/002_seed_initial_project.sql
```

### Method 2: Using AWS RDS with Secrets Manager

```bash
# Get database credentials
DB_SECRET_ARN="arn:aws:secretsmanager:region:account:secret:secret-name"
DB_ENDPOINT=$(terraform output -raw database_endpoint)
DB_NAME=$(terraform output -raw database_name)

# Extract credentials
DB_USER=$(aws secretsmanager get-secret-value \
  --secret-id "${DB_SECRET_ARN}" \
  --query 'SecretString' \
  --output text | jq -r '.username')

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "${DB_SECRET_ARN}" \
  --query 'SecretString' \
  --output text | jq -r '.password')

# Apply migrations
for migration in migrations/*.sql; do
  echo "Applying migration: $migration"
  docker run --rm -i postgres:15 psql \
    "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}?sslmode=require" \
    < "$migration"
done
```

### Method 3: Using psql directly (if installed)

```bash
# Set environment variables
export PGHOST="your-db-host"
export PGPORT="5432"
export PGDATABASE="davidshaevel"
export PGUSER="dbadmin"
export PGPASSWORD="your-password"
export PGSSLMODE="require"

# Apply migrations
psql -f migrations/001_create_projects_table.sql
psql -f migrations/002_seed_initial_project.sql
```

## Migration History

| Migration | Date | Description | Applied To |
|-----------|------|-------------|------------|
| 001 | 2025-10-31 | Create projects table | dev |
| 002 | 2025-10-31 | Seed initial project | dev |

## Schema: projects table

```sql
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    "imageUrl" VARCHAR(500),
    "projectUrl" VARCHAR(500),
    "githubUrl" VARCHAR(500),
    technologies TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### Indexes

- `idx_projects_is_active` on `"isActive"` column
- `idx_projects_sort_order` on `"sortOrder"` column

### Triggers

- `update_projects_updated_at` - Automatically updates `"updatedAt"` timestamp on row updates

## Verification

After applying migrations, verify the schema:

```bash
# Using Docker
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require" \
  -c "\d projects"

# Using psql directly
psql -c "\d projects"
```

Query data:

```bash
# Using Docker
docker run --rm -i postgres:15 psql \
  "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require" \
  -c "SELECT id, title, array_length(technologies, 1) as tech_count FROM projects;"

# Using psql directly
psql -c "SELECT id, title, array_length(technologies, 1) as tech_count FROM projects;"
```

## Future Migrations

When creating new migrations:

1. Use sequential numbering: `00X_descriptive_name.sql`
2. Include IF NOT EXISTS clauses for idempotency
3. Document the migration in this README
4. Test in development environment first
5. Update the Migration History table above

## Notes

- All migrations should be idempotent (safe to run multiple times)
- Use `IF NOT EXISTS` and `IF NOT EXISTS` clauses where appropriate
- Always use transactions for multi-statement migrations
- Test migrations in development before applying to production
- Keep migrations small and focused on a single change
- Document breaking changes and required application updates
