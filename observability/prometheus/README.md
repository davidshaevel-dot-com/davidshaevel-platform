# Prometheus Configuration

This directory contains the Prometheus configuration and Dockerfile for the DavidShaevel.com platform observability stack.

## Overview

Prometheus is deployed as an ECS Fargate service that scrapes metrics from:
- **Backend API** (`/api/metrics`) - Node.js application metrics
- **Frontend** (`/metrics`) - Next.js application metrics
- **Prometheus itself** - Self-monitoring metrics

## Architecture

```
┌─────────────────────────────────────┐
│      ECS Fargate Service            │
│  ┌───────────────────────────────┐ │
│  │   Prometheus Container        │ │
│  │   - Port 9090                 │ │
│  │   - EFS mount: /prometheus    │ │
│  └───────────────────────────────┘ │
│              │                      │
│              ▼                      │
│   Service Discovery (Cloud Map)    │
│   - dev-davidshaevel-backend.davidshaevel.local     │
│   - dev-davidshaevel-frontend.davidshaevel.local    │
└─────────────────────────────────────┘
```

## Configuration

### `prometheus.yml`

Main configuration file that defines:
- **Global settings:** Scrape/evaluation intervals, external labels
- **Scrape configs:** Jobs for backend, frontend, and Prometheus self-monitoring
- **Service discovery:** Uses AWS Cloud Map DNS names
- **Metric filtering:** Keeps only relevant metrics to reduce storage

### `Dockerfile`

Custom Docker image based on `prom/prometheus:v2.48.1` with:
- Custom prometheus.yml configuration
- Health check endpoint (`/-/healthy`)
- 15-day data retention
- Web lifecycle API enabled for config reloads

## Metrics Collected

### Backend Metrics (`backend_*`)
- `backend_uptime_seconds` - Application uptime
- `backend_info` - Application version and environment info
- `nodejs_memory_usage_bytes` - Node.js memory usage (rss, heap, external)
- `backend_http_request_duration_seconds` - HTTP request latency histogram
- `backend_http_requests_total` - HTTP request counter by path/method/status
- `backend_db_query_duration_seconds` - Database query latency histogram

### Frontend Metrics (`frontend_*`)
- `frontend_uptime_seconds` - Application uptime
- `frontend_info` - Application version and environment info
- `nodejs_memory_usage_bytes` - Node.js memory usage
- `frontend_http_request_duration_seconds` - HTTP request latency histogram
- `frontend_http_requests_total` - HTTP request counter by path/method/status

### Prometheus Metrics (`prometheus_*`)
- `prometheus_tsdb_storage_blocks_bytes` - TSDB storage size
- `prometheus_tsdb_head_series` - Number of active time series
- `prometheus_target_scrapes_total` - Scrape counter per target
- `prometheus_target_up` - Target health (1 = up, 0 = down)

## Storage

Prometheus data is stored in EFS at `/prometheus` with:
- **Retention:** 15 days
- **Format:** TSDB (Time Series Database) blocks
- **Backup:** EFS automatic backups enabled

## Access

Prometheus UI is accessible at:
- **Internal:** `http://dev-davidshaevel-prometheus.davidshaevel.local:9090`
- **External (via ALB):** `https://davidshaevel.com/prometheus`

## Monitoring Prometheus

Health check endpoint: `http://dev-davidshaevel-prometheus.davidshaevel.local:9090/-/healthy`

Query self-monitoring metrics:
```promql
# Scrape success rate
rate(prometheus_target_scrapes_total[5m])

# Number of active time series
prometheus_tsdb_head_series

# Storage size
prometheus_tsdb_storage_blocks_bytes
```

## Troubleshooting

### Prometheus not scraping targets

1. Check service discovery:
   ```bash
   dig +short dev-davidshaevel-backend.davidshaevel.local
   dig +short dev-davidshaevel-frontend.davidshaevel.local
   ```

2. Check Prometheus targets page (from within VPC): `http://prometheus:9090/targets`
   - Or via ALB: `https://davidshaevel.com/prometheus/targets`

3. Check security groups allow traffic from Prometheus to backend/frontend

### High memory usage

1. Check number of active series:
   ```promql
   prometheus_tsdb_head_series
   ```

2. Reduce retention time if needed (edit Dockerfile CMD)

3. Add more aggressive metric filtering in prometheus.yml

## Configuration Reload

Prometheus supports live config reload:
```bash
# Send SIGHUP signal to Prometheus process
# Note: This command uses short hostname and must be run from within the VPC
# (e.g., via ECS Exec, bastion host, or VPN connection where Cloud Map DNS resolution works)
curl -X POST http://prometheus:9090/-/reload
```

Or redeploy the ECS service to pick up new configuration.
