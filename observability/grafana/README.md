# Grafana Configuration

This directory contains the Grafana configuration, Dockerfile, and pre-configured dashboards for the DavidShaevel.com platform observability stack.

## Overview

Grafana is deployed as an ECS Fargate service that visualizes metrics from Prometheus, providing:
- Pre-configured dashboards for application and infrastructure monitoring
- Automatic Prometheus datasource configuration
- Persistent storage for custom dashboards and settings

## Architecture

```
┌──────────────────────────────────-----─┐
│      ECS Fargate Service               │
│  ┌─────────────────────────────---──┐  │
│  │   Grafana Container              │  │
│  │   - Port 3000                    │  │
│  │   - EFS mount: /var/lib/grafana  │  │
│  └────────────────────────────---───┘  │
│              │                         │
│              ▼                         │
│      Prometheus Datasource             │
│   (via service discovery)              │
└──────────────────────────────────---───┘
```

## Directory Structure

```
grafana/
├── Dockerfile                              # Custom Grafana image (grafana:10.4.2)
├── README.md                               # This file
└── provisioning/
    ├── datasources/
    │   └── prometheus.yml                  # Auto-configured Prometheus datasource
    ├── dashboards/
    │   └── default.yml                     # Dashboard provider config
    └── dashboard-definitions/
        ├── application-overview.json       # Application health and status
        ├── nodejs-performance.json         # Node.js memory, CPU, event loop
        └── infrastructure-overview.json    # ECS tasks, ALB metrics
```

## Configuration Files

### `provisioning/datasources/prometheus.yml`

Automatically configures Prometheus as the default datasource when Grafana starts.

**Key settings:**
- **URL:** `http://prometheus.davidshaevel.local:9090` (via AWS Cloud Map service discovery)
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

### 2. Node.js Performance

**Purpose:** Detailed Node.js runtime metrics for both services

**Panels:**
- Memory usage breakdown (RSS, Heap Used, Heap Total, External)
- Event loop lag and utilization
- Active handles and requests
- Garbage collection metrics

**Refresh:** 30 seconds

### 3. Infrastructure Overview

**Purpose:** ECS task and load balancer metrics

**Panels:**
- ECS task CPU and memory utilization
- ALB request counts and latency
- Target group health status
- Error rates and 4xx/5xx responses

**Refresh:** 30 seconds

## Storage

Grafana data is stored in EFS at `/var/lib/grafana` including:
- **Database:** SQLite database with dashboard configs and user settings
- **Plugins:** Installed Grafana plugins
- **Custom dashboards:** User-created dashboards

## Access

Grafana UI is accessible at:
- **Internal:** `http://grafana.davidshaevel.local:3000` (via AWS Cloud Map)
- **External (via CloudFront):** `https://grafana.davidshaevel.com`

**Default credentials:**
- Username: `admin`
- Password: Set via environment variable `GF_SECURITY_ADMIN_PASSWORD`

## Adding New Dashboards

### Option 1: Via UI (Recommended for development)

1. Access Grafana at `https://grafana.davidshaevel.com`
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

Health check endpoint: `http://grafana.davidshaevel.local:3000/api/health`

Response when healthy:
```json
{
  "database": "ok",
  "version": "10.4.2"
}
```

## Troubleshooting

### Grafana can't reach Prometheus

1. Check service discovery DNS:
   ```bash
   dig +short prometheus.davidshaevel.local
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

## CloudFront Integration

Grafana is accessed via CloudFront CDN at `https://grafana.davidshaevel.com`. The CDN configuration ensures Grafana's dynamic content is handled correctly.

### Key Configuration for Grafana

**Cache Policy (`default_ttl = 0`):**

CloudFront is configured with `default_ttl = 0`, which means:
- CloudFront honors origin `Cache-Control` headers when present
- When no `Cache-Control` header is present, content is NOT cached
- This prevents stale dashboard data from being served to users

This is critical for Grafana because dashboards display real-time metrics that should never be cached incorrectly.

**Origin Request Policy (AllViewer):**

All viewer headers are forwarded to the origin, ensuring:
- Authentication headers (cookies, authorization) reach Grafana correctly
- All query parameters are forwarded for dashboard filtering

### Related Documentation

For full technical details on the CloudFront cache policy configuration, including Next.js RSC header support, see the [CDN Module README](../../terraform/modules/cdn/README.md#custom-nextjs-cache-policy-v11).

## Resources

- **Official Docs:** https://grafana.com/docs/grafana/latest/
- **Dashboard JSON Schema:** https://grafana.com/docs/grafana/latest/dashboards/json-model/
- **Provisioning:** https://grafana.com/docs/grafana/latest/administration/provisioning/

---

**Document Version:** 1.2
**Last Updated:** December 13, 2025

### Changelog

#### v1.2 (December 13, 2025)
- Fixed service discovery DNS names (removed `dev-davidshaevel-` prefix)
- Updated external URL to `https://grafana.davidshaevel.com` (CloudFront subdomain)
- Added Node.js Performance and Infrastructure Overview dashboards to directory structure
- Added descriptions for all 3 pre-configured dashboards
- Updated Grafana version reference to 10.4.2

#### v1.1 (December 12, 2025)
- Added CloudFront Integration section
- Documented cache policy and origin request policy configuration

#### v1.0 (November 2025)
- Initial Grafana configuration documentation
