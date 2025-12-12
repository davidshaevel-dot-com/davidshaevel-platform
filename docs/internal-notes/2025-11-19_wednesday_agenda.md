# Wednesday, November 19, 2025 - Session Agenda

**Focus:** TT-25 Phase 8-9 - Enhanced Application Metrics Endpoints
**Estimated Duration:** 4-6 hours
**Priority:** High - Continue observability stack implementation

---

## 🎯 Session Goals

### Primary Objective
Implement enhanced Prometheus metrics endpoints in both backend and frontend applications to provide rich monitoring data beyond basic health checks.

### Success Criteria
- ✅ Backend `/api/metrics` endpoint exposing custom application metrics
- ✅ Frontend `/api/metrics` endpoint exposing client-side performance metrics
- ✅ Prometheus successfully scraping and storing enhanced metrics
- ✅ Metrics follow Prometheus naming conventions and best practices
- ✅ All changes deployed to production environment

---

## 📋 Work Breakdown

### Block 1: Backend Enhanced Metrics (2-3 hours)

**TT-25 Phase 8: Backend Prometheus Metrics**

#### 1.1 Research & Planning (30 min)
- [ ] Research `prom-client` library for Node.js/Nest.js
- [ ] Review Prometheus metric types (Counter, Gauge, Histogram, Summary)
- [ ] Identify key metrics to expose:
  - HTTP request counters (by endpoint, method, status code)
  - Request duration histograms (response time percentiles)
  - Active connections gauge
  - Database query metrics (count, duration)
  - Error rates by type
- [ ] Review Prometheus naming conventions (prefix, units, suffixes)
- [ ] Check if `/api/metrics` endpoint already exists (may be placeholder)

#### 1.2 Implementation (60-90 min)
- [ ] Install `prom-client` package: `npm install prom-client`
- [ ] Create Prometheus metrics module in backend:
  - `src/metrics/metrics.module.ts`
  - `src/metrics/metrics.service.ts`
  - `src/metrics/metrics.controller.ts`
- [ ] Define metric collectors:
  - Default Node.js metrics (memory, CPU, event loop)
  - HTTP request counter: `http_requests_total{method, endpoint, status}`
  - HTTP request duration: `http_request_duration_seconds{method, endpoint}`
  - Database queries: `db_queries_total{operation}`, `db_query_duration_seconds`
- [ ] Implement middleware to track HTTP metrics
- [ ] Update `/api/metrics` endpoint to expose Prometheus format
- [ ] Test metrics endpoint locally: `curl http://localhost:3001/api/metrics`

#### 1.3 Testing & Validation (30 min)
- [ ] Verify metrics format (Prometheus text exposition format)
- [ ] Generate sample traffic to populate metrics
- [ ] Confirm metric names follow conventions
- [ ] Run backend integration tests
- [ ] Validate TypeScript types and ESLint compliance

---

### Block 2: Frontend Enhanced Metrics (1.5-2 hours)

**TT-25 Phase 9: Frontend Prometheus Metrics**

#### 2.1 Research & Planning (20 min)
- [ ] Research `prom-client` compatibility with Next.js 16
- [ ] Identify frontend-specific metrics to expose:
  - Page view counters (by route)
  - Client-side rendering time
  - API call counters (to backend)
  - Error boundaries triggered
  - Static asset load times
- [ ] Determine Next.js API route approach (`app/api/metrics/route.ts`)

#### 2.2 Implementation (60-90 min)
- [ ] Install `prom-client` package: `npm install prom-client`
- [ ] Create metrics utilities in frontend:
  - `lib/metrics.ts` - Metric registry and collectors
  - `app/api/metrics/route.ts` - Metrics endpoint
- [ ] Define metric collectors:
  - Default Node.js metrics (for server-side)
  - Page views: `page_views_total{route}`
  - SSR duration: `ssr_duration_seconds{route}`
  - API calls: `api_calls_total{endpoint, status}`
  - Client errors: `client_errors_total{type}`
- [ ] Implement tracking in components/middleware
- [ ] Update `/api/metrics` endpoint
- [ ] Test metrics endpoint locally: `curl http://localhost:3000/api/metrics`

#### 2.3 Testing & Validation (20-30 min)
- [ ] Verify metrics format matches Prometheus spec
- [ ] Generate sample traffic (visit pages, trigger API calls)
- [ ] Confirm metric names follow conventions
- [ ] Run frontend build and type checking
- [ ] Validate ESLint compliance

---

### Block 3: Deployment & Integration (1-1.5 hours)

#### 3.1 Docker Image Builds (20-30 min)
- [ ] Build backend image with metrics:
  ```bash
  cd backend
  docker build -t backend:$(git rev-parse --short HEAD)-metrics .
  ```
- [ ] Build frontend image with metrics:
  ```bash
  cd frontend
  docker build -t frontend:$(git rev-parse --short HEAD)-metrics .
  ```
- [ ] Test images locally with Docker Compose (if available)

#### 3.2 ECR Push & ECS Deployment (20-30 min)
- [ ] Tag and push backend image to ECR
- [ ] Tag and push frontend image to ECR
- [ ] Update Terraform variables with new image tags
- [ ] Run `terraform plan` to review changes
- [ ] Run `terraform apply` to deploy new images
- [ ] Monitor ECS task deployments (health checks)

#### 3.3 Prometheus Integration Testing (20-30 min)
- [ ] Wait for Prometheus scrape interval (15 seconds)
- [ ] Verify new metrics appearing in Prometheus:
  ```bash
  aws ecs execute-command \
    --cluster dev-davidshaevel-cluster \
    --task <prometheus-task-id> \
    --container prometheus \
    --interactive \
    --command "/bin/sh"
  # Inside container:
  wget -qO- localhost:9090/api/v1/targets
  wget -qO- localhost:9090/api/v1/query?query=http_requests_total
  ```
- [ ] Confirm metrics from backend and frontend are being scraped
- [ ] Check metric cardinality (not too many unique label combinations)
- [ ] Verify no errors in Prometheus logs

---

### Block 4: Documentation & Cleanup (30 min)

#### 4.1 Git Workflow
- [ ] Create feature branch: `david/tt-25-enhanced-metrics-endpoints`
- [ ] Commit backend changes with descriptive message
- [ ] Commit frontend changes with descriptive message
- [ ] Commit Terraform variable updates (new image tags)
- [ ] Push branch to remote
- [ ] Create PR with comprehensive description

#### 4.2 Linear Updates
- [ ] Update TT-25 with Phase 8-9 completion details
- [ ] Add comment with metrics exposed and validation results
- [ ] Update project status in Linear project

#### 4.3 Documentation
- [ ] Create session summary: `docs/2025-11-19_enhanced_metrics_session_summary.md`
- [ ] Update README.md with Phase 8-9 completion
- [ ] Update AGENT_HANDOFF.md with current state

---

## 🔧 Technical Notes

### Prometheus Metric Naming Conventions
- **Format:** `<prefix>_<metric_name>_<unit>_<suffix>`
- **Units:** `seconds`, `bytes`, `total`, `ratio`
- **Suffixes:** `_total` (counters), `_bucket`/`_sum`/`_count` (histograms)
- **Labels:** Use sparingly, avoid high cardinality (e.g., user IDs, timestamps)

### Example Metrics

**Backend (`/api/metrics`):**
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/health",status="200"} 42
http_requests_total{method="POST",endpoint="/api/projects",status="201"} 5

# HELP http_request_duration_seconds HTTP request duration
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/api/health",le="0.1"} 40
http_request_duration_seconds_bucket{method="GET",endpoint="/api/health",le="0.5"} 42
http_request_duration_seconds_sum{method="GET",endpoint="/api/health"} 2.1
http_request_duration_seconds_count{method="GET",endpoint="/api/health"} 42
```

**Frontend (`/api/metrics`):**
```
# HELP page_views_total Total page views
# TYPE page_views_total counter
page_views_total{route="/"} 15
page_views_total{route="/about"} 8
page_views_total{route="/projects"} 12

# HELP ssr_duration_seconds Server-side rendering duration
# TYPE ssr_duration_seconds histogram
ssr_duration_seconds_bucket{route="/",le="0.1"} 10
ssr_duration_seconds_bucket{route="/",le="0.5"} 15
ssr_duration_seconds_sum{route="/"} 1.2
ssr_duration_seconds_count{route="/"} 15
```

---

## ⚠️ Potential Issues & Solutions

### Issue 1: Metric Cardinality Explosion
- **Problem:** Too many unique label combinations (e.g., including user IDs)
- **Solution:** Use aggregated labels (e.g., `status_class="2xx"` instead of `status="200"`)

### Issue 2: Next.js API Route Compatibility
- **Problem:** `prom-client` may not work seamlessly with Next.js 16 App Router
- **Solution:** Use edge runtime compatible alternatives or server-only approach

### Issue 3: Prometheus Scrape Timeout
- **Problem:** Metrics endpoint takes too long to respond (default 10s timeout)
- **Solution:** Optimize metric collection, reduce label cardinality, increase timeout

### Issue 4: Docker Image Size Increase
- **Problem:** `prom-client` adds to image size
- **Solution:** Acceptable for observability value, monitor final image sizes

---

## 📊 Success Metrics

- ✅ **Backend metrics:** 5+ custom metrics exposed
- ✅ **Frontend metrics:** 4+ custom metrics exposed
- ✅ **Prometheus scraping:** All targets healthy with new metrics
- ✅ **Deployment:** Zero downtime, all health checks passing
- ✅ **Documentation:** Session summary and updates complete
- ✅ **Code quality:** All tests passing, ESLint clean

---

## 🚀 Stretch Goals (if time permits)

- [ ] Add Grafana-ready metric labels (align with future dashboard needs)
- [ ] Implement business-specific metrics (e.g., project creation rate)
- [ ] Add custom recording rules to Prometheus config for common queries
- [ ] Create sample PromQL queries for testing dashboard visualizations

---

**Estimated Total Time:** 4-6 hours
**Priority:** High
**Dependencies:** TT-25 Phase 7 complete ✅

**Next Session (Thursday):** TT-25 Phase 10 - Grafana Dashboard Deployment
