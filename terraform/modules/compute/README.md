# Compute Module - ECS Fargate and Application Load Balancer

This Terraform module creates an AWS ECS Fargate cluster with Application Load Balancer (ALB) for hosting containerized applications.

**Module Version:** 1.0
**Created:** October 26, 2025
**Last Updated:** October 26, 2025

---

## Overview

This module implements a complete containerized application platform using:
- **ECS Fargate:** Serverless container orchestration
- **Application Load Balancer:** HTTP/HTTPS traffic distribution
- **CloudWatch:** Container logs and monitoring
- **IAM:** Least-privilege access control
- **Secrets Manager:** Secure database credential access

---

## Architecture

```
Internet
    |
    v
Application Load Balancer (Public Subnets)
    |
    |-- Frontend Target Group (port 3000)
    |       |
    |       v
    |   Frontend ECS Service (Private App Subnets)
    |       |
    |       v
    |   Frontend Tasks (2x for HA)
    |
    |-- Backend Target Group (port 3001)
            |
            v
        Backend ECS Service (Private App Subnets)
            |
            v
        Backend Tasks (2x for HA)
            |
            v
        RDS PostgreSQL (Private DB Subnets)
```

### Components Created

**Step 8: ECS Cluster + ALB**
- ECS Fargate cluster with Container Insights
- Application Load Balancer (internet-facing)
- 2 Target groups (frontend:3000, backend:3001)
- HTTP listener with path-based routing
- Health checks for both services

**Step 9: Task Definitions + Services**
- Frontend task definition (Next.js placeholder)
- Backend task definition (Nest.js placeholder)
- 2 ECS services with desired count of 2 each
- IAM roles (task execution + task roles)
- CloudWatch log groups (7-day retention)
- Database integration via Secrets Manager

---

## Usage

### Basic Example

```hcl
module "compute" {
  source = "../../modules/compute"

  # Context
  project_name = "myproject"
  environment  = "dev"

  # Networking (from networking module)
  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  private_app_subnet_ids     = module.networking.private_app_subnet_ids
  alb_security_group_id      = module.networking.alb_security_group_id
  frontend_security_group_id = module.networking.frontend_app_security_group_id
  backend_security_group_id  = module.networking.backend_app_security_group_id

  # Database (from database module)
  database_endpoint   = module.database.db_instance_endpoint
  database_port       = module.database.db_instance_port
  database_name       = module.database.db_name
  database_secret_arn = module.database.secret_arn

  # Container images (use placeholders initially)
  frontend_image = "nginx:latest"
  backend_image  = "nginx:latest"

  # Task sizing
  frontend_task_cpu    = 256
  frontend_task_memory = 512
  backend_task_cpu     = 256
  backend_task_memory  = 512

  # Service configuration
  desired_count_frontend = 2
  desired_count_backend  = 2

  # CloudWatch
  log_retention_days      = 7
  enable_container_insights = true

  # Tags
  common_tags = {
    Environment = "dev"
    Project     = "myproject"
    ManagedBy   = "Terraform"
  }
}
```

### Production Example

```hcl
module "compute" {
  source = "../../modules/compute"

  # ... same as basic but with:

  # Production-sized tasks
  frontend_task_cpu    = 512
  frontend_task_memory = 1024
  backend_task_cpu     = 512
  backend_task_memory  = 1024

  # Higher availability
  desired_count_frontend = 4
  desired_count_backend  = 4

  # Production settings
  enable_deletion_protection = true
  log_retention_days        = 30
  enable_alb_access_logs    = true
  alb_access_logs_bucket    = "my-alb-logs-bucket"
}
```

---

## Inputs

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `project_name` | Project name for resource naming | `string` |
| `environment` | Environment (dev/staging/prod) | `string` |
| `vpc_id` | VPC ID where resources deploy | `string` |
| `public_subnet_ids` | Public subnets for ALB (min 2) | `list(string)` |
| `private_app_subnet_ids` | Private subnets for ECS tasks (min 2) | `list(string)` |
| `alb_security_group_id` | ALB security group ID | `string` |
| `frontend_security_group_id` | Frontend security group ID | `string` |
| `backend_security_group_id` | Backend security group ID | `string` |
| `database_endpoint` | Database endpoint (host:port) | `string` |
| `database_name` | Database name | `string` |
| `database_secret_arn` | Secrets Manager ARN for DB credentials | `string` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `frontend_image` | Frontend container image | `string` | `"nginx:latest"` |
| `backend_image` | Backend container image | `string` | `"nginx:latest"` |
| `frontend_task_cpu` | Frontend CPU units (256=0.25 vCPU) | `number` | `256` |
| `frontend_task_memory` | Frontend memory (MiB) | `number` | `512` |
| `backend_task_cpu` | Backend CPU units | `number` | `256` |
| `backend_task_memory` | Backend memory (MiB) | `number` | `512` |
| `desired_count_frontend` | Frontend task count | `number` | `2` |
| `desired_count_backend` | Backend task count | `number` | `2` |
| `database_port` | Database port | `number` | `5432` |
| `enable_deletion_protection` | Enable ALB deletion protection | `bool` | `false` |
| `alb_idle_timeout` | ALB idle timeout (seconds) | `number` | `60` |
| `enable_alb_access_logs` | Enable ALB access logs | `bool` | `false` |
| `alb_access_logs_bucket` | S3 bucket for ALB logs | `string` | `""` |
| `frontend_health_check_path` | Frontend health check path | `string` | `"/"` |
| `backend_health_check_path` | Backend health check path | `string` | `"/health"` |
| `health_check_interval` | Health check interval (seconds) | `number` | `30` |
| `health_check_timeout` | Health check timeout (seconds) | `number` | `5` |
| `healthy_threshold` | Healthy threshold count | `number` | `2` |
| `unhealthy_threshold` | Unhealthy threshold count | `number` | `3` |
| `health_check_grace_period` | ECS health check grace period | `number` | `60` |
| `log_retention_days` | CloudWatch log retention | `number` | `7` |
| `enable_container_insights` | Enable Container Insights | `bool` | `true` |
| `common_tags` | Tags for all resources | `map(string)` | `{}` |

---

## Outputs

### ECS Cluster

| Name | Description |
|------|-------------|
| `ecs_cluster_id` | ECS cluster ID |
| `ecs_cluster_name` | ECS cluster name |
| `ecs_cluster_arn` | ECS cluster ARN |

### Application Load Balancer

| Name | Description |
|------|-------------|
| `alb_id` | ALB ID |
| `alb_arn` | ALB ARN |
| `alb_dns_name` | ALB DNS name (use this to access application) |
| `alb_zone_id` | ALB Route53 zone ID |
| `alb_arn_suffix` | ALB ARN suffix for CloudWatch |

### Target Groups

| Name | Description |
|------|-------------|
| `frontend_target_group_arn` | Frontend target group ARN |
| `backend_target_group_arn` | Backend target group ARN |

### ECS Services

| Name | Description |
|------|-------------|
| `frontend_service_name` | Frontend service name |
| `backend_service_name` | Backend service name |
| `frontend_task_definition_arn` | Frontend task definition ARN |
| `backend_task_definition_arn` | Backend task definition ARN |

### IAM Roles

| Name | Description |
|------|-------------|
| `task_execution_role_arn` | Task execution role ARN |
| `frontend_task_role_arn` | Frontend task role ARN |
| `backend_task_role_arn` | Backend task role ARN |

### CloudWatch

| Name | Description |
|------|-------------|
| `frontend_log_group_name` | Frontend log group name |
| `backend_log_group_name` | Backend log group name |

### Application URLs

| Name | Description |
|------|-------------|
| `application_url` | Main application URL |
| `frontend_url` | Frontend URL |
| `backend_url` | Backend API URL |

---

## Features

### High Availability
- ALB deployed across 2+ availability zones
- ECS tasks distributed across 2+ AZs
- Multiple tasks per service (default: 2)
- Automatic task replacement on failure

### Security
- Tasks in private subnets (no internet access)
- ALB in public subnets only
- Least-privilege IAM roles
- Database credentials via Secrets Manager (not in environment)
- Security groups restrict traffic flow
- Container Insights for monitoring

### Monitoring & Observability
- CloudWatch Container Insights (optional)
- CloudWatch Logs for all containers
- Configurable log retention
- ALB access logs (optional)
- Health checks for all services
- Target group metrics

### Cost Optimization
- Fargate Spot capacity available
- Right-sized task definitions
- Configurable task counts (can scale to 0)
- Short log retention in dev (7 days)

---

## Container Images

### Placeholder Images (Initial Deployment)

The module defaults to `nginx:latest` for both frontend and backend. This allows infrastructure testing before application code is ready.

**Expected behavior with placeholders:**
- Tasks will start successfully
- Health checks may fail (nginx doesn't have /health endpoint)
- ALB will show targets as unhealthy
- This is expected and normal

### Replacing with Real Images

Once your applications are containerized (TT-18, TT-19):

```hcl
frontend_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/myproject-frontend:latest"
backend_image  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/myproject-backend:latest"
```

---

## Database Integration

The backend task automatically receives database credentials via AWS Secrets Manager:

**Environment variables set:**
- `DB_HOST`: Database hostname
- `DB_PORT`: Database port (5432)
- `DB_NAME`: Database name

**Secrets injected:**
- `DB_USERNAME`: From Secrets Manager
- `DB_PASSWORD`: From Secrets Manager

Your backend application can use these variables to connect to PostgreSQL.

---

## Routing

### HTTP Listener (Port 80)

**Default action:** Forward to frontend target group

**Path-based routing:**
- `/` → Frontend service
- `/api/*` → Backend service

### Example URLs

After deployment, access via ALB DNS name:
- `http://dev-myproject-alb-123456789.us-east-1.elb.amazonaws.com/` → Frontend
- `http://dev-myproject-alb-123456789.us-east-1.elb.amazonaws.com/api/health` → Backend

---

## Cost Estimate

### Development Environment (2 tasks each)

**Monthly costs:**
- ALB: ~$16-20
- Frontend tasks (2 x 0.25 vCPU, 0.5 GB): ~$7
- Backend tasks (2 x 0.25 vCPU, 0.5 GB): ~$7
- CloudWatch Logs (7 days, low volume): ~$1
- **Total: ~$31-35/month**

### Production Environment (4 tasks each)

**Monthly costs:**
- ALB: ~$16-20
- Frontend tasks (4 x 0.5 vCPU, 1 GB): ~$28
- Backend tasks (4 x 0.5 vCPU, 1 GB): ~$28
- CloudWatch Logs (30 days): ~$5
- ALB access logs: ~$2
- **Total: ~$79-83/month**

**Note:** Costs vary based on:
- Task count and size
- Data transfer volume
- Log volume
- ALB request count

---

## Health Checks

### ALB Target Group Health Checks

- **Interval:** 30 seconds (configurable)
- **Timeout:** 5 seconds (configurable)
- **Healthy threshold:** 2 consecutive successes
- **Unhealthy threshold:** 3 consecutive failures
- **Frontend path:** `/` (returns 200-299)
- **Backend path:** `/health` (returns 200-299)

### Container Health Checks

- **Frontend:** `curl http://localhost:3000/`
- **Backend:** `curl http://localhost:3001/health`
- **Interval:** 30 seconds
- **Retries:** 3
- **Start period:** 60 seconds

---

## Troubleshooting

### Tasks Won't Start

**Check:**
1. IAM task execution role has proper permissions
2. Container image exists and is accessible
3. CloudWatch log groups exist
4. Security groups allow outbound traffic for image pull

**View logs:**
```bash
aws logs tail /ecs/dev-myproject/frontend --follow
aws logs tail /ecs/dev-myproject/backend --follow
```

### Unhealthy Targets

**With placeholder images (nginx):**
- This is expected - nginx doesn't have `/health` endpoint
- Frontend may be healthy (nginx serves `/`)
- Backend will be unhealthy (no `/health`)

**With real applications:**
1. Check health check path matches your app
2. Verify app listens on correct port
3. Check security group allows ALB → tasks
4. Review CloudWatch logs for errors

### Database Connection Issues

**Check:**
1. Database security group allows backend security group
2. Secrets Manager ARN is correct
3. Backend task role has Secrets Manager permissions
4. Database is in same VPC

**Test connection from task:**
```bash
# Get into running container
aws ecs execute-command --cluster dev-myproject-cluster \
  --task <task-id> --container backend --interactive --command /bin/sh

# Test database connection
nc -zv <db-host> 5432
```

---

## Migration Path

### Phase 1: Infrastructure (This Module)
✅ Deploy ECS cluster + ALB with placeholder images
✅ Verify infrastructure creates successfully
✅ Check CloudWatch logs are working

### Phase 2: Application Development (TT-18, TT-19)
- Build Next.js frontend with health endpoint
- Build Nest.js backend with `/health` endpoint
- Create Dockerfiles
- Test locally with Docker Compose

### Phase 3: Container Registry (TT-23)
- Create ECR repositories
- Build and push images
- Update module variables with ECR URIs

### Phase 4: Deployment
- Update task definitions with real images
- Deploy via `terraform apply`
- Verify health checks pass
- Test application functionality

---

## Dependencies

This module requires outputs from:
- **Networking module:** VPC, subnets, security groups
- **Database module:** RDS endpoint, credentials ARN

Must be deployed in order:
1. Networking module
2. Database module
3. **Compute module** (this module)

---

## Resources Created

**Total:** ~25-30 resources

- 1 ECS cluster
- 1 ECS cluster capacity provider config
- 2 CloudWatch log groups
- 3 IAM roles (task execution, frontend task, backend task)
- 3 IAM policies/attachments
- 1 Application Load Balancer
- 2 Target groups
- 1 HTTP listener
- 1 Listener rule
- 2 Task definitions
- 2 ECS services
- 1 Data source (region)

---

## Changelog

### Version 1.0 (October 26, 2025)
- Initial module creation
- ECS Fargate cluster with Container Insights
- Application Load Balancer with 2 target groups
- Frontend and backend task definitions
- Frontend and backend ECS services
- IAM roles with least-privilege access
- CloudWatch logging
- Secrets Manager integration for database
- Path-based routing (/api/* → backend)
- Comprehensive health checks

---

## References

- [AWS ECS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [ECS Task Definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html)
- [ECS Services](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html)
- [Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)

---

**Module Maintainer:** Platform Engineering Team
**Support:** See project documentation
