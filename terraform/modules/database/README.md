# Database Module

## Overview

This module provisions an RDS PostgreSQL database with enterprise-grade security, monitoring, and backup capabilities. It follows AWS best practices and integrates seamlessly with the networking infrastructure.

## Features

- **RDS PostgreSQL 15** - PostgreSQL 15.12 with RDS-managed password
- **Automated Backups** - 7-day retention with configurable backup window
- **Encryption at Rest** - AWS KMS encryption enabled by default
- **AWS Secrets Manager** - RDS-managed secret with automatic rotation support
- **CloudWatch Monitoring** - Comprehensive alarms for CPU, connections, memory, and storage
- **Performance Insights** - Free 7-day performance metrics
- **Private Subnets Only** - Database in isolated network tier
- **Security Group Integration** - Uses existing database security group
- **No Credentials in State** - Passwords never stored in Terraform state

## Usage

```hcl
module "database" {
  source = "../../modules/database"

  # Environment configuration
  environment  = "dev"
  project_name = "davidshaevel"

  # Networking inputs (from networking module)
  vpc_id                        = module.networking.vpc_id
  private_db_subnet_ids         = module.networking.private_db_subnet_ids
  database_security_group_id    = module.networking.database_security_group_id

  # Database configuration
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = "davidshaevel"
  db_master_username = "dbadmin"

  # High availability
  multi_az            = false  # Set to true for production
  deletion_protection = false  # Set to true for production

  # Tags
  tags = {
    Environment = "dev"
    Project     = "davidshaevel"
    ManagedBy   = "Terraform"
  }
}
```

## Resources Created

- 1 RDS PostgreSQL instance (with RDS-managed secret)
- 1 RDS DB subnet group
- 1 IAM role for enhanced monitoring
- 4 CloudWatch alarms (CPU, connections, storage, memory)
- 1 optional parameter group (if enabled)

## Input Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| environment | Environment name (dev, prod) | string |
| project_name | Project name for resource naming | string |
| vpc_id | VPC ID where the database will be deployed | string |
| private_db_subnet_ids | List of private database subnet IDs | list(string) |
| database_security_group_id | Security group ID for database access | string |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| engine | Database engine | string | "postgres" |
| engine_version | Database engine version | string | "15.12" |
| instance_class | RDS instance class | string | "db.t3.micro" |
| db_name | Name of the database to create | string | "davidshaevel" |
| db_master_username | Master username | string | "dbadmin" |
| allocated_storage | Allocated storage in GB | number | 20 |
| max_allocated_storage | Maximum allocated storage for autoscaling | number | 100 |
| storage_type | Storage type (gp3, gp2, io1) | string | "gp3" |
| backup_retention_period | Number of days to retain automated backups | number | 7 |
| backup_window | Daily time range for backups (UTC) | string | "03:00-04:00" |
| maintenance_window | Weekly maintenance window | string | "sun:04:00-sun:05:00" |
| auto_minor_version_upgrade | Enable automatic minor version upgrades | bool | true |
| multi_az | Enable Multi-AZ deployment | bool | false |
| deletion_protection | Enable deletion protection | bool | false |
| performance_insights_enabled | Enable Performance Insights | bool | true |
| performance_insights_retention_period | Performance Insights retention period in days | number | 7 |
| create_parameter_group | Whether to create a custom parameter group | bool | false |
| parameter_group_family | Parameter group family | string | "postgres15" |
| max_connections_threshold | Threshold for max connections alarm | number | 80 |
| low_free_storage_threshold_bytes | Threshold for low free storage alarm (bytes) | number | 10737418240 (10 GB) |
| low_freeable_memory_threshold_bytes | Threshold for low freeable memory alarm (bytes) | number | 536870912 (512 MB) |
| alarm_actions | List of ARNs to notify when alarm triggers | list(string) | [] |
| tags | Common tags to apply to all resources | map(string) | {} |

## Outputs

| Name | Description |
|------|-------------|
| db_instance_id | RDS instance ID |
| db_instance_arn | RDS instance ARN |
| db_instance_endpoint | RDS instance endpoint (hostname) |
| db_instance_address | RDS instance hostname (DNS name) |
| db_instance_port | RDS instance port |
| db_name | Database name |
| db_username | Master username (sensitive) |
| secret_arn | ARN of the RDS-managed database credentials secret |
| connection_string | Database connection string (without credentials) |
| jdbc_connection_string | JDBC connection string (without credentials) |
| alarm_high_cpu_arn | ARN of the high CPU alarm |
| alarm_high_connections_arn | ARN of the high connections alarm |
| alarm_low_free_storage_arn | ARN of the low free storage alarm |
| alarm_low_freeable_memory_arn | ARN of the low freeable memory alarm |

## Security Features

### Network Isolation
- Database deployed in private subnets only
- No public access (`publicly_accessible = false`)
- Access controlled via security group (backend tier only)

### Encryption
- Encryption at rest enabled (AWS KMS)
- Database backups encrypted
- Logs encrypted in CloudWatch

### Secrets Management
- Credentials managed by RDS using `manage_master_user_password = true`
- Automatic secret creation in AWS Secrets Manager
- Secret rotation support (configured separately)
- **Critical**: No credentials stored in Terraform state or code
- Secret ARN format: `arn:aws:secretsmanager:region:account:secret:rds!db-instance-id`

## Monitoring

### CloudWatch Alarms
The module creates the following alarms:

1. **High CPU** - Triggers when CPU > 80% for 2 consecutive periods
2. **High Connections** - Triggers when connections > configured threshold (default: 80)
3. **Low Free Storage** - Triggers when free storage < 10 GB
4. **Low Freeable Memory** - Triggers when freeable memory < 512 MB

### Performance Insights
- Enabled by default
- 7-day retention (free tier)
- Deep dive into database performance
- Query-level insights

### Enhanced Monitoring
- 60-second interval monitoring
- Granular metrics for CPU, memory, I/O
- CloudWatch Logs integration

## Backups

### Automated Backups
- Enabled by default
- 7-day retention period
- Backup window: 03:00-04:00 UTC (configurable)
- Automatic snapshots before upgrades

### Manual Snapshots
- Create via AWS Console or CLI
- Best practice before major changes

## Cost Estimate

### Development (db.t3.micro)
- Instance: ~$15/month
- Storage (20 GB): ~$2.30/month
- I/O requests: ~$0.50/month
- **Total: ~$17.80/month**

### Production (db.t3.small Multi-AZ)
- Instance: ~$60/month
- Storage (100 GB): ~$11.50/month
- I/O requests: ~$1/month
- **Total: ~$72.50/month**

*Note: Costs vary by region and usage*

## Best Practices

### Development Environment
- Use `db.t3.micro` instance class
- Single-AZ deployment (cost savings)
- Disable deletion protection for flexibility
- Keep backup retention at 7 days

### Production Environment
- Use `db.t3.small` or larger instance class
- Enable Multi-AZ for high availability
- Enable deletion protection
- Increase backup retention (up to 35 days)
- Enable detailed monitoring
- Configure SNS notifications for alarms

## Connection Examples

### From Backend Application (Node.js/Nest.js)
```javascript
// Retrieve credentials from RDS-managed secret in Secrets Manager
// Use the secret_arn output from the Terraform module
// Example: module.database.secret_arn
const secretArn = process.env.DATABASE_SECRET_ARN;

const secret = await secretsManager.getSecretValue({
  SecretId: secretArn
}).promise();

const credentials = JSON.parse(secret.SecretString);

// Connect using TypeORM
const connection = createConnection({
  type: 'postgres',
  host: credentials.host,
  port: credentials.port,
  database: credentials.dbname,
  username: credentials.username,
  password: credentials.password,
});
```

### From AWS CLI
```bash
# Get credentials from RDS-managed secret in Secrets Manager
# Use the secret_arn output from the Terraform module
aws secretsmanager get-secret-value \
  --secret-id <secret-arn-from-terraform-output>

# Connect via psql (from EC2 in same VPC)
psql -h <endpoint> -U <username> -d davidshaevel
```

## Troubleshooting

### Connection Issues
1. Verify security group allows traffic from backend subnet
2. Check that database is in "available" state
3. Verify credentials in Secrets Manager
4. Confirm network ACLs allow traffic

### Performance Issues
1. Review Performance Insights dashboards
2. Check CloudWatch alarms for resource constraints
3. Consider upgrading instance class
4. Review and optimize slow queries

### Backup Issues
1. Verify backup window is valid
2. Check backup retention period setting
3. Review maintenance window conflicts

## Related Modules

- `networking` - Provides VPC, subnets, and security groups
- `compute` - Backend application that connects to the database (future)

## Version History

- **v1.1.0** - Updated to use RDS-managed passwords, fixed CloudWatch alarm metrics
  - Use `manage_master_user_password = true` for secure password management
  - Fixed low free storage alarm to use `FreeStorageSpace` metric
  - Updated PostgreSQL engine version to 15.12
  - Removed redundant tags covered by provider default_tags
- **v1.0.0** - Initial release with RDS PostgreSQL support

## License

This module is part of the DavidShaevel.com Platform Engineering Portfolio project.
