# TT-63: Node.js Profiling & Debugging Hands-On Lab - Session Agenda

**Date:** Sunday, December 14, 2025
**Linear Issue:** [TT-63](https://linear.app/davidshaevel-dot-com/issue/TT-63/nodejs-profiling-debugging-hands-on-lab)
**Branch:** `david/tt-63-nodejs-profiling-debugging-hands-on-lab`

---

## Session Overview

Resume work on the Node.js profiling and debugging hands-on lab. Files were drafted in a separate agent session in the job-searches-2025-q4 repo and need to be integrated into the davidshaevel-platform repo.

**Key Enhancement:** Added Node Inspector integration plan with three-part lab structure covering local debugging, production-style profiling, and remote container debugging.

---

## Files Created/Modified This Session

### From job-searches-2025-q4 repo:

**Backend Lab Module (`backend/src/lab/`):**
- `lab.module.ts` - NestJS module registration
- `lab.controller.ts` - REST endpoints (status, event-loop-jam, memory-leak, memory-clear, heap-snapshot, cpu-profile)
- `lab.service.ts` - Core profiling logic using node:inspector, v8, and fs
- `lab.guard.ts` - Security guard with LAB_ENABLE, LAB_TOKEN, LAB_ALLOW_PROD checks

**New Files Created:**
- `docker-compose.yml` - Local development with Inspector port (9229) exposed
- `backend/Dockerfile.dev` - Development Dockerfile with hot reload support
- `docs/labs/node-profiling-and-debugging.md` - Enhanced 3-part lab guide (640+ lines)

---

## Enhanced Lab Structure

The lab now covers three debugging approaches:

| Part | Approach | Best For |
|------|----------|----------|
| **Part 1** | Local Inspector (Chrome DevTools) | Development, learning, interactive debugging |
| **Part 2** | HTTP Endpoints (Production-safe) | Staging, production incidents, remote systems |
| **Part 3** | Remote Inspector (Advanced) | Deep debugging in non-prod containers |

### Part 1: Local Development Debugging (NEW)
- Step 1.1: Start development environment with Inspector
- Step 1.2: Attach Chrome DevTools
- Step 1.3: Breakpoint debugging (step through code)
- Step 1.4: Live CPU profiling (Performance tab)
- Step 1.5: Live heap inspection (Memory tab)

### Part 2: Production-Style Debugging (Enhanced)
- Step 2.0: Confirm baseline
- Step 2.1: Enable lab endpoints
- Step 2.2: Reproduce event loop jam
- Step 2.3: Capture CPU profile (file-based)
- Step 2.4: Reproduce memory growth
- Step 2.5: Capture heap snapshots
- Step 2.6: Cleanup

### Part 3: Remote Debugging (NEW)
- Step 3.1: Prerequisites
- Step 3.2: Enable Inspector in ECS task
- Step 3.3: Port forward via SSM
- Step 3.4: Attach Chrome DevTools
- Step 3.5: Cleanup

### Appendix
- When to use each approach
- Lab endpoint reference
- Environment variables
- Troubleshooting guide
- Further reading

---

## Todo List for Lab Completion

### Phase 1: Code Integration (TODAY - COMPLETE)
- [x] Create Linear issue TT-63 for tracking
- [x] Rename branch to include Linear issue number
- [x] Copy lab files from job-searches-2025-q4 to davidshaevel-platform
- [x] Create session agenda document
- [x] Create Docker Compose with Inspector support
- [x] Create Dockerfile.dev for development
- [x] Enhance lab documentation with 3-part structure
- [x] Add Node Inspector sections (Part 1)
- [x] Add Remote Debugging section (Part 3)
- [x] Add Appendix with troubleshooting
- [ ] Verify LabModule is properly imported in app.module.ts
- [ ] Add missing API prefix to lab controller routes (`/api/lab/*`)

### Phase 2: Local Testing
- [ ] Test lab endpoints locally with Docker Compose
- [ ] Verify token authentication works correctly
- [ ] Test each endpoint:
  - [ ] GET /api/lab/status
  - [ ] POST /api/lab/event-loop-jam
  - [ ] POST /api/lab/memory-leak
  - [ ] POST /api/lab/memory-clear
  - [ ] POST /api/lab/heap-snapshot
  - [ ] POST /api/lab/cpu-profile
- [ ] Verify Inspector attachment works
- [ ] Test breakpoint debugging workflow
- [ ] Verify Prometheus metrics reflect induced conditions

### Phase 3: Helper Scripts
- [ ] Create `scripts/export-backend-ecs-artifact.sh` for retrieving profiles from ECS
- [ ] Document script usage in lab guide
- [ ] Test script against dev/staging environment

### Phase 4: Documentation Enhancements
- [ ] Add architecture diagram showing lab flow
- [ ] Add screenshots of Chrome DevTools analysis
- [ ] Add example flamegraph interpretation
- [ ] Create interview talking points for lab demonstration

### Phase 5: Deployment
- [ ] Deploy to dev environment with LAB_ENABLE=true
- [ ] Test full lab workflow end-to-end
- [ ] Create Terraform variables for lab configuration
- [ ] Document deployment considerations

---

## Lab Endpoints Summary

| Endpoint | Method | Purpose | Parameters |
|----------|--------|---------|------------|
| `/api/lab/status` | GET | Check lab status and retained memory | - |
| `/api/lab/event-loop-jam` | POST | Block event loop | `ms` (default: 2000, max: 60000) |
| `/api/lab/memory-leak` | POST | Retain memory buffers | `mb` (default: 64, max: 1024) |
| `/api/lab/memory-clear` | POST | Clear retained memory | - |
| `/api/lab/heap-snapshot` | POST | Write heap snapshot to /tmp | - |
| `/api/lab/cpu-profile` | POST | Capture CPU profile | `seconds` (default: 30, max: 120) |

---

## Safety Controls

1. **LAB_ENABLE** - Must be `true` to enable endpoints (default: disabled)
2. **LAB_TOKEN** - Required header `x-lab-token` for authentication
3. **LAB_ALLOW_PROD** - Additional flag required when NODE_ENV=production
4. **Inspector port** - Only exposed in development Docker Compose (never in production!)

---

## Environment Variables

```bash
# Enable lab endpoints (NEVER in production without LAB_ALLOW_PROD)
LAB_ENABLE=true

# Secret token for lab endpoint access
LAB_TOKEN=your-secure-random-token

# Only set if intentionally enabling in production (dangerous!)
LAB_ALLOW_PROD=true

# Node Inspector (development only)
NODE_OPTIONS="--inspect=0.0.0.0:9229"
```

---

## Session Progress

| Task | Status | Notes |
|------|--------|-------|
| Create Linear issue TT-63 | ✅ Done | https://linear.app/davidshaevel-dot-com/issue/TT-63 |
| Rename branch | ✅ Done | david/tt-63-nodejs-profiling-debugging-hands-on-lab |
| Copy lab files | ✅ Done | 4 backend files |
| Create Docker Compose | ✅ Done | Inspector port 9229 exposed |
| Create Dockerfile.dev | ✅ Done | Development with hot reload |
| Enhance lab documentation | ✅ Done | 3-part structure, 640+ lines |
| Update TT-63 with plan | ✅ Done | Node Inspector integration plan |
| Create session agenda | ✅ Done | This document |
| Verify app.module.ts | ⏳ Pending | |
| Local testing | ⏳ Pending | |
| Helper scripts | ⏳ Pending | |
| Deployment | ⏳ Pending | |

---

## Interview Talking Points Enabled

1. "I understand tradeoffs between interactive and file-based debugging"
2. "I know how to debug containerized Node.js services in AWS"
3. "I implement safety controls for debugging in production"
4. "I can demonstrate live profiling with Chrome DevTools"
5. "I can explain V8 heap structure and garbage collection"

---

## Next Steps

1. Verify the LabModule import in app.module.ts is correct
2. Add `/api` prefix to the lab controller routes
3. Test locally with Docker Compose
4. Create PR for initial lab code integration
