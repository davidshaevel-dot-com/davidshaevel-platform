# Session Agenda - December 4, 2025 (Thursday)

**Branch:** `david/tt-25-phase-5-dashboards`
**Focus:** Complete TT-25 Phase 5 - Grafana Dashboards
**Linear Issue:** [TT-25](https://linear.app/davidshaevel-dot-com/issue/TT-25/implement-comprehensive-observability-with-grafana-and-prometheus)

---

## Session Context

TT-25 is marked as "Done" in Linear, but Phase 5 (Dashboards) appears incomplete. The original scope called for 3 dashboards:

1. **Application overview dashboard** - Partially exists (basic health/memory only)
2. **Infrastructure dashboard** - Missing
3. **Node.js performance dashboard** - Missing

### Current State

**Grafana Status:** ✅ Healthy at https://grafana.davidshaevel.com
**Prometheus Status:** ✅ 5/5 targets healthy (2 backend + 2 frontend + 1 prometheus)

**Existing Dashboard:**
- `application-overview.json` - Basic panels (status, uptime, memory)

**Available Metrics:**

| Source | Metrics |
|--------|---------|
| Backend | `http_request_duration_seconds`, `http_requests_total`, `http_request_errors_total`, `db_query_*`, `backend_info`, `backend_uptime_seconds`, Node.js defaults |
| Frontend | `frontend_page_views_total`, `frontend_api_calls_total`, `frontend_api_call_duration_seconds`, `frontend_info`, `frontend_uptime_seconds`, Node.js defaults |

---

## Goals for Today

### 1. Housekeeping ✅
- [x] Create feature branch
- [x] Move date-prefixed files from `docs/` to `docs/internal-notes/`
- [x] Create session agenda

### 2. Create Missing Dashboards

#### Infrastructure Dashboard (~45 min)
Create `infrastructure-overview.json` with panels for:
- ECS service health (backend/frontend up status)
- Task counts and memory/CPU usage
- Request rates and error rates
- Prometheus scrape health

#### Node.js Performance Dashboard (~45 min)
Create `nodejs-performance.json` with panels for:
- Heap memory usage (used vs total)
- External memory
- Event loop lag
- Active handles/requests
- GC pause times (if available)

#### Enhanced Application Overview (~30 min)
Update `application-overview.json` to add:
- HTTP request rate (requests/second)
- HTTP latency percentiles (p50, p90, p99)
- Error rate percentage
- Page views (frontend)
- API call duration

### 3. Deploy and Verify (~30 min)
- Rebuild Grafana Docker image
- Push to ECR
- Deploy via Terraform or ECS update
- Verify all dashboards load with data

---

## Files to Create/Modify

**New Files:**
- `observability/grafana/provisioning/dashboard-definitions/infrastructure-overview.json`
- `observability/grafana/provisioning/dashboard-definitions/nodejs-performance.json`

**Modified Files:**
- `observability/grafana/provisioning/dashboard-definitions/application-overview.json`

---

## Success Criteria

- [ ] Infrastructure dashboard shows ECS/service health metrics
- [ ] Node.js dashboard shows memory, event loop, GC metrics
- [ ] Application overview includes HTTP request/latency/error metrics
- [ ] All 3 dashboards visible in Grafana UI
- [ ] All panels show data (not "No data" or errors)
- [ ] PR created and ready for review

---

## Notes

**Site Redirect Issue:** The main site (davidshaevel.com) is returning 301 redirects. This is separate from the dashboard work but should be investigated.

**Estimated Time:** 2-3 hours total
