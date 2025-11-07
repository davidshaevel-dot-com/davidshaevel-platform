# Grafana Configuration

This directory contains the Grafana configuration, Dockerfile, and pre-configured dashboards for the DavidShaevel.com platform observability stack.

## Overview

Grafana is deployed as an ECS Fargate service that visualizes metrics from Prometheus, providing:
- Pre-configured dashboards for application and infrastructure monitoring
- Automatic Prometheus datasource configuration
- Persistent storage for custom dashboards and settings

## Architecture

```
┌─────────────────────────────────────┐
│      ECS Fargate Service            │
│  ┌───────────────────────────────┐ │
│  │   Grafana Container           │ │
│  │   - Port 3000                 │ │
│  │   - EFS mount: /var/lib/grafana  │ │
│  └───────────────────────────────┘ │
│              │                      │
│              ▼                      │
│      Prometheus Datasource         │
│   (via service discovery)          │
└─────────────────────────────────────┘
```

## Directory Structure

```
grafana/
├── Dockerfile                              # Custom Grafana image
├── README.md                               # This file
└── provisioning/
    ├── datasources/
    │   └── prometheus.yml                  # Auto-configured Prometheus datasource
    ├── dashboards/
    │   └── default.yml                     # Dashboard provider config
    └── dashboard-definitions/
        └── application-overview.json       # Application metrics dashboard
```

## Configuration Files

### `provisioning/datasources/prometheus.yml`

Automatically configures Prometheus as the default datasource when Grafana starts.

**Key settings:**
- **URL:** `http://dev-davidshaevel-prometheus.davidshaevel.local:9090` (via service discovery)
- **Access mode:** Proxy (Grafana queries Prometheus on behalf of browser)
- **Default:** Yes (primary datasource)
- **Editable:** No (prevents accidental changes)

### `provisioning/dashboards/default.yml`

Configures Grafana to automatically load dashboards from `/etc/grafana/provisioning/dashboard-definitions/`.

**Key settings:**
- **Auto-loading:** Dashboards are loaded on Grafana startup
- **Updates allowed:** Users can modify dashboards via UI
- **Refresh interval:** 10 seconds (picks up new dashboard files)

### `provisioning/dashboard-definitions/application-overview.json`

Pre-configured dashboard showing:
- **Backend Status:** Health indicator (HEALTHY/UNHEALTHY)
- **Frontend Status:** Health indicator (HEALTHY/UNHEALTHY)
- **Backend Uptime:** Time since last restart
- **Memory Usage:** Node.js memory metrics (RSS, Heap, External)

## Pre-configured Dashboards

### 1. Application Overview

**Purpose:** High-level view of application health and performance

**Panels:**
- Backend/Frontend status indicators
- Backend uptime
- Memory usage trends for both services

**Refresh:** 30 seconds

## Storage

Grafana data is stored in EFS at `/var/lib/grafana` including:
- **Database:** SQLite database with dashboard configs and user settings
- **Plugins:** Installed Grafana plugins
- **Custom dashboards:** User-created dashboards

## Access

Grafana UI is accessible at:
- **Internal:** `http://dev-davidshaevel-grafana.davidshaevel.local:3000`
- **External (via ALB):** `https://davidshaevel.com/grafana`

**Default credentials:**
- Username: `admin`
- Password: Set via environment variable `GF_SECURITY_ADMIN_PASSWORD`

## Adding New Dashboards

### Option 1: Via UI (Recommended for development)

1. Access Grafana at `https://davidshaevel.com/grafana`
2. Click **+** → **New Dashboard**
3. Add panels and configure queries
4. Click **Save** → Export as JSON
5. Copy JSON to `provisioning/dashboard-definitions/`
6. Rebuild and redeploy Grafana container

### Option 2: Via Provisioning (Recommended for production)

1. Create new JSON file in `provisioning/dashboard-definitions/`
2. Follow the structure of `application-overview.json`
3. Rebuild Grafana Docker image
4. Redeploy ECS service

## Monitoring Grafana

Health check endpoint: `http://dev-davidshaevel-grafana.davidshaevel.local:3000/api/health`

Response when healthy:
```json
{
  "database": "ok",
  "version": "10.2.3"
}
```

## Troubleshooting

### Grafana can't reach Prometheus

1. Check service discovery DNS:
   ```bash
   dig +short dev-davidshaevel-prometheus.davidshaevel.local
   ```

2. Check Grafana datasource status:
   - Navigate to **Configuration** → **Data Sources** → **Prometheus**
   - Click **Test** button
   - Should show "Data source is working"

3. Check security groups allow traffic from Grafana to Prometheus port 9090

### Dashboards not loading

1. Check dashboard provisioning logs in CloudWatch:
   ```bash
   aws logs tail /ecs/dev-davidshaevel/grafana --since 10m
   ```

2. Verify dashboard JSON is valid:
   ```bash
   cat provisioning/dashboard-definitions/application-overview.json | jq .
   ```

3. Check file permissions in container:
   ```bash
   # Files should be owned by grafana:grafana
   ls -la /etc/grafana/provisioning/dashboard-definitions/
   ```

### Lost admin password

1. Set new password via environment variable in Terraform
2. Redeploy ECS service
3. Grafana will reset admin password on startup

## Customization

### Change default theme

Add to Grafana environment variables in Terraform:
```hcl
{
  name  = "GF_USERS_DEFAULT_THEME"
  value = "dark"  # or "light"
}
```

### Enable anonymous access

```hcl
{
  name  = "GF_AUTH_ANONYMOUS_ENABLED"
  value = "true"
},
{
  name  = "GF_AUTH_ANONYMOUS_ORG_ROLE"
  value = "Viewer"
}
```

### Configure SMTP for alerts

```hcl
{
  name  = "GF_SMTP_ENABLED"
  value = "true"
},
{
  name  = "GF_SMTP_HOST"
  value = "smtp.example.com:587"
}
```

## Useful Queries

### Backend health
```promql
backend_info
```

### Memory usage percentage
```promql
100 * nodejs_memory_usage_bytes{type="heapUsed"} / nodejs_memory_usage_bytes{type="heapTotal"}
```

### HTTP request rate
```promql
rate(backend_http_requests_total[5m])
```

## Resources

- **Official Docs:** https://grafana.com/docs/grafana/latest/
- **Dashboard JSON Schema:** https://grafana.com/docs/grafana/latest/dashboards/json-model/
- **Provisioning:** https://grafana.com/docs/grafana/latest/administration/provisioning/
