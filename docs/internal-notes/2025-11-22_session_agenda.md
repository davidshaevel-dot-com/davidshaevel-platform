# Session Agenda: Saturday, November 22, 2025

**Goal:** Verify Grafana deployment, expose it publicly via ALB, and ensure secure access.

## 🎯 Objectives

1.  **Verification:**
    *   Verify internal Grafana access and health status.
    *   Confirm authentication (admin password) is working.
2.  **Public Access (ALB):**
    *   Configure ALB Listener Rule to route `grafana.davidshaevel.com` to Grafana service.
    *   Update Terraform modules (`compute`, `observability`) to support this.
3.  **DNS (Cloudflare):**
    *   Add CNAME record for `grafana` pointing to ALB DNS name.
4.  **Testing:**
    *   Create `scripts/test-grafana-deployment.sh` to automate verification.

## 📋 Plan

### 1. Linear Issue Tracking
- [ ] Create new issue: "Verify Access to Grafana and Configure Public Access"
- [ ] Update issue with detailed task list.

### 2. Infrastructure Updates (Terraform)
- [ ] **Compute Module:** Output ALB Listener ARNs (HTTP/HTTPS).
- [ ] **Observability Module:**
    - [ ] Create `aws_lb_target_group` for Grafana.
    - [ ] Create `aws_lb_listener_rule` for Host header `grafana.davidshaevel.com`.
    - [ ] Update `aws_ecs_service` to attach to Load Balancer.
- [ ] **Environment (Dev):** Wire up listener ARN from `compute` to `observability`.

### 3. Verification Script
- [ ] Create `scripts/test-grafana-deployment.sh` based on Prometheus script.
- [ ] Test checks:
    - [ ] Service status
    - [ ] Task health
    - [ ] Internal HTTP access (health endpoint)
    - [ ] Public HTTP access (after ALB config)

### 4. Cloudflare DNS
- [ ] Manual or Terraform update for CNAME record.

### 5. Documentation
- [ ] Update session summary.


