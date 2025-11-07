# Observability Architecture

Comprehensive observability stack for the DavidShaevel.com platform using Prometheus and Grafana on AWS ECS Fargate.

## Overview

The observability stack provides real-time monitoring and visualization of application and infrastructure metrics across the platform.

**Components:**
- **Prometheus:** Metrics collection and storage
- **Grafana:** Dashboards and visualization
- **AWS Cloud Map:** Service discovery
- **AWS EFS:** Persistent storage
- **AWS ALB:** External access routing

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                    AWS VPC (dev-davidshaevel)                    │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │          Application Load Balancer (Public)                │ │
│  │  /prometheus/* → Prometheus Target Group (9090)           │ │
│  │  /grafana/* → Grafana Target Group (3000)                 │ │
│  └───────────────────────────────────────────────────────────┘ │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              ECS Cluster (Fargate)                        │ │
│  │                                                           │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │ │
│  │  │  Backend     │  │  Frontend    │  │  Prometheus  │  │ │
│  │  │  Service     │  │  Service     │  │  Service     │  │ │
│  │  │  (2 tasks)   │  │  (2 tasks)   │  │  (1 task)    │  │ │
│  │  │  :3001       │  │  :3000       │  │  :9090       │  │ │
│  │  │              │  │              │  │              │  │ │
│  │  │ /api/metrics │  │  /metrics    │  │  scrapes ────┼──┼──┐
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │ │ │
│  │         ▲                 ▲                 │           │ │ │
│  │         └─────────────────┴─────────────────┘           │ │ │
│  │                   Scrape every 15s                      │ │ │
│  │                                                          │ │ │
│  │                          ┌──────────────┐               │ │ │
│  │                          │   Grafana    │               │ │ │
│  │                          │   Service    │               │ │ │
│  │                          │   (1 task)   │               │ │ │
│  │                          │   :3000      │               │ │ │
│  │                          │              │               │ │ │
│  │                          │  queries ────┼───────────────┘ │ │
│  │                          └──────────────┘                 │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         Service Discovery (AWS Cloud Map)                 │ │
│  │  Namespace: davidshaevel.local                           │ │
│  │  - dev-davidshaevel-backend.davidshaevel.local → Backend tasks            │ │
│  │  - dev-davidshaevel-frontend.davidshaevel.local → Frontend tasks          │ │
│  │  - dev-davidshaevel-prometheus.davidshaevel.local → Prometheus task       │ │
│  │  - dev-davidshaevel-grafana.davidshaevel.local → Grafana task             │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Elastic File System (EFS)                    │ │
│  │                                                           │ │
│  │  ┌─────────────────────┐  ┌──────────────────────────┐  │ │
│  │  │ Prometheus Data     │  │  Grafana Data            │  │ │
│  │  │ /prometheus         │  │  /var/lib/grafana        │  │ │
│  │  │ - TSDB blocks       │  │  - SQLite database       │  │ │
│  │  │ - 15 day retention  │  │  - Custom dashboards     │  │ │
│  │  └─────────────────────┘  └──────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Metrics Collection (Prometheus)

1. **Scraping:** Prometheus scrapes metrics endpoints every 15 seconds
   - Backend: `http://dev-davidshaevel-backend.davidshaevel.local:3001/api/metrics`
   - Frontend: `http://dev-davidshaevel-frontend.davidshaevel.local:3000/metrics`
   - Self: `http://localhost:9090/metrics`

2. **Storage:** Metrics are stored in TSDB format on EFS
   - Time series data organized in 2-hour blocks
   - 15-day retention policy
   - Automatic compaction and cleanup

3. **Service Discovery:** Prometheus resolves service DNS names via AWS Cloud Map
   - Dynamic target discovery (no hardcoded IPs)
   - Automatic failover if tasks restart

### Visualization (Grafana)

1. **Datasource:** Grafana queries Prometheus via service discovery
   - URL: `http://dev-davidshaevel-prometheus.davidshaevel.local:9090`
   - Query type: PromQL (Prometheus Query Language)

2. **Dashboards:** Pre-configured dashboards auto-load on startup
   - Provisioned from JSON files in Docker image
   - Users can create additional dashboards (stored in EFS)

3. **Access:** Users access Grafana via ALB
   - External URL: `https://davidshaevel.com/grafana`
   - ALB forwards to Grafana tasks on port 3000

## Components Deep Dive

### Prometheus

**Configuration:** `observability/prometheus/prometheus.yml`

**Key features:**
- **Scrape interval:** 15s (balance between freshness and overhead)
- **Retention:** 15 days (sufficient for short-term trends)
- **Storage:** EFS-backed TSDB (persistent across restarts)
- **Targets:** Backend, Frontend, Self

**Resource allocation:**
- CPU: 256 (0.25 vCPU)
- Memory: 512 MB
- Storage: EFS (grows as needed, ~1-2 GB typical)

**Metrics exported:**
- Application metrics (custom)
- Node.js process metrics (built-in)
- Prometheus internal metrics (scrapes, storage, etc.)

### Grafana

**Configuration:** `observability/grafana/provisioning/`

**Key features:**
- **Auto-provisioning:** Datasources and dashboards load automatically
- **Persistent storage:** EFS for user data and custom dashboards
- **Pre-configured:** Ready-to-use dashboards included

**Resource allocation:**
- CPU: 256 (0.25 vCPU)
- Memory: 512 MB
- Storage: EFS (~100-500 MB typical)

**Dashboards:**
- Application Overview: Backend/Frontend health and performance
- Infrastructure: ECS tasks, ALB, RDS metrics (planned)
- Node.js Performance: Memory, CPU, event loop (planned)

### Service Discovery (AWS Cloud Map)

**Namespace:** `davidshaevel.local` (private DNS)

**How it works:**
1. ECS registers tasks with Cloud Map on startup
2. Cloud Map creates DNS A records for each service
3. Prometheus/Grafana resolve service names to task IPs
4. If tasks restart with new IPs, DNS updates automatically

**Benefits:**
- No hardcoded IPs in configuration
- Automatic failover and load balancing
- Works seamlessly with ECS service auto-scaling

### Persistent Storage (EFS)

**File systems:**
- `prometheus-data`: Prometheus TSDB storage
- `grafana-data`: Grafana SQLite database and dashboards

**Configuration:**
- **Encryption:** At rest (AES-256) and in transit (TLS)
- **Performance mode:** General Purpose (sufficient for observability workloads)
- **Throughput mode:** Bursting (scales with file system size)
- **Lifecycle management:** None (retain all data within retention period)
- **Backup:** AWS Backup enabled (daily snapshots, 7-day retention)

**Access points:**
- Define POSIX user/group for Prometheus (nobody:nogroup, UID/GID 65534)
- Define POSIX user/group for Grafana (grafana:grafana, UID/GID 472)
- Isolates data between services

## Security

### Network Security

**Security groups:**
- Prometheus SG: Allow inbound 9090 from Grafana SG and ALB SG
- Grafana SG: Allow inbound 3000 from ALB SG
- Backend SG: Allow inbound 3001 from Prometheus SG, ALB SG, and Frontend SG
- Frontend SG: Allow inbound 3000 from Prometheus SG and ALB SG

**Private subnet placement:**
- All ECS tasks run in private subnets (no direct internet access)
- Outbound traffic via NAT gateway
- Inbound traffic only via ALB

### IAM Permissions

**Prometheus task role:**
- `cloudwatch:GetMetricData` (for CloudWatch metrics scraping - future)
- `cloudwatch:ListMetrics` (for CloudWatch discovery - future)

**Grafana task role:**
- Minimal permissions (no AWS API access needed)

**Task execution roles:**
- `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`
- `logs:CreateLogStream`, `logs:PutLogEvents`
- `elasticfilesystem:ClientMount`, `elasticfilesystem:ClientWrite`

### Data Security

**EFS encryption:**
- At rest: AWS KMS encryption (aws/elasticfilesystem key)
- In transit: TLS 1.2+ (enabled via mount options)

**Secrets management:**
- Grafana admin password: Stored in AWS Secrets Manager
- Injected as environment variable at task startup

## Cost Estimation

### Monthly Costs (Development Environment)

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| Prometheus ECS Task | 256 CPU / 512 MB, 1 task, 24/7 | $8.50 |
| Grafana ECS Task | 256 CPU / 512 MB, 1 task, 24/7 | $8.50 |
| EFS Storage | ~5 GB (Prometheus + Grafana) | $1.50 |
| EFS Throughput | Bursting mode | $0.00 |
| Data Transfer | Minimal (internal VPC) | $0.50 |
| **Total** | | **~$19/month** |

### Cost Optimization Strategies

1. **Reduce task sizes:** 128 CPU / 256 MB may be sufficient (~$4.25/task/month)
2. **Scale down off-hours:** Stop tasks nights/weekends in dev (not recommended)
3. **Use Fargate Spot:** Up to 70% savings (not for production)
4. **Lifecycle policies:** Delete old EFS data beyond retention

## Monitoring the Monitors

### Prometheus Health

**Metrics to watch:**
- `prometheus_tsdb_head_series`: Number of active time series (high = expensive)
- `prometheus_tsdb_storage_blocks_bytes`: Storage usage (ensure fits in EFS free tier)
- `prometheus_target_up`: Target availability (1 = up, 0 = down)
- `prometheus_target_scrape_duration_seconds`: Scrape latency

**Alerts:**
- Target down for > 5 minutes
- Storage usage > 80% of EFS allocation
- Scrape duration > 5 seconds

### Grafana Health

**Metrics to watch:**
- `grafana_api_response_status_total`: API response codes
- `grafana_database_conn_*`: Database connection pool metrics
- `process_resident_memory_bytes`: Memory usage

**Health check:**
- Endpoint: `http://grafana:3000/api/health`
- Expected: `{"database":"ok"}`

## Disaster Recovery

### Backup Strategy

**EFS snapshots:**
- Automated via AWS Backup
- Schedule: Daily at 3 AM UTC
- Retention: 7 days
- Recovery time: < 1 hour

### Recovery Procedures

**Prometheus data loss:**
1. Restore from EFS snapshot
2. Redeploy Prometheus ECS service
3. Data gap = time since last snapshot

**Grafana dashboard loss:**
1. Restore from EFS snapshot, OR
2. Re-provision dashboards from Git (preferred)

**Complete observability stack failure:**
1. Ensure backend/frontend continue running (no dependency)
2. Restore EFS from snapshot
3. Redeploy both ECS services via Terraform
4. Verify service discovery working

## Operational Runbook

See [observability-runbook.md](./observability-runbook.md) for:
- Deployment procedures
- Common troubleshooting scenarios
- How to add new metrics
- How to create new dashboards
- Performance tuning guide

## Future Enhancements

1. **Alerting:** Configure Prometheus alerting rules + Grafana notifications
2. **CloudWatch integration:** Scrape RDS, ALB, ECS metrics from CloudWatch
3. **Distributed tracing:** Add Jaeger/Tempo for request tracing
4. **Log aggregation:** Integrate CloudWatch Logs with Loki
5. **Auto-scaling:** Scale Prometheus horizontally with Thanos
6. **Long-term storage:** Archive metrics to S3 via Thanos/Cortex

## References

- **Prometheus Documentation:** https://prometheus.io/docs/
- **Grafana Documentation:** https://grafana.com/docs/
- **AWS EFS:** https://docs.aws.amazon.com/efs/
- **AWS Cloud Map:** https://docs.aws.amazon.com/cloud-map/
- **ECS Service Discovery:** https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html
