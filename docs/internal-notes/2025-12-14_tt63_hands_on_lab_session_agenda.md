# TT-63: Node.js Profiling & Debugging Hands-On Lab - Session Agenda

**Date:** Sunday, December 14, 2025
**Linear Issue:** [TT-63](https://linear.app/davidshaevel-dot-com/issue/TT-63/nodejs-profiling-debugging-hands-on-lab)
**Phase 1 Branch:** `david/tt-63-nodejs-profiling-debugging-hands-on-lab`
**Phase 2 Branch:** `david/tt-63-phase2-local-testing`
**Status:** ✅ Phase 1 & 2 Complete (PRs #67 and #68 merged)

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

### Phase 1: Code Integration ✅ COMPLETE (PR #67 - Dec 14)
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
- [x] Verify LabModule is properly imported in app.module.ts
- [x] Add missing API prefix to lab controller routes (`/api/lab/*`)

### Phase 2: Local Testing ✅ COMPLETE (PR #68 - Dec 15)
- [x] Test lab endpoints locally with Docker Compose
- [x] Verify token authentication works correctly
- [x] Test each endpoint:
  - [x] GET /api/lab/status (403 without token, 200 with token)
  - [x] POST /api/lab/event-loop-jam (1.057s blocking)
  - [x] POST /api/lab/memory-leak (67MB retained)
  - [x] POST /api/lab/memory-clear (cleared successfully)
  - [x] POST /api/lab/heap-snapshot (~27MB file created)
  - [x] POST /api/lab/cpu-profile (5.224s, 409 on concurrent)
- [x] Verify Inspector attachment works
- [x] Test breakpoint debugging workflow
- [x] Test live CPU profiling (flame chart visible)
- [x] Test live heap inspection (Buffer objects found)

**Test Results:** 13/13 PASS (9 automated + 4 manual Chrome DevTools)

**Key Fixes Made:**
1. TypeScript error in lab.service.ts - fixed inspector callback type
2. Inspector source files not visible - switched to NestJS debug mode
3. Security warnings added per Gemini Code Assist feedback

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
| Verify app.module.ts | ✅ Done | LabModule imported correctly |
| **Phase 1 PR #67** | ✅ Merged | Dec 14, 2025 |
| Local testing | ✅ Done | 13/13 tests passing |
| Create local testing guide | ✅ Done | 382 lines |
| Fix TypeScript error | ✅ Done | Inspector callback type |
| Fix Inspector source visibility | ✅ Done | NestJS debug mode |
| Add security warnings | ✅ Done | Gemini Code Assist feedback |
| **Phase 2 PR #68** | ✅ Merged | Dec 15, 2025 |
| Helper scripts | ⏳ Pending | Phase 3 |
| Documentation enhancements | ⏳ Pending | Phase 4 |
| Deployment | ⏳ Pending | Phase 5 |

---

## Interview Talking Points Enabled

1. "I understand tradeoffs between interactive and file-based debugging"
2. "I know how to debug containerized Node.js services in AWS"
3. "I implement safety controls for debugging in production"
4. "I can demonstrate live profiling with Chrome DevTools"
5. "I can explain V8 heap structure and garbage collection"

---

## Next Steps (Phases 3-5)

**Phase 3: Helper Scripts**
1. Create `scripts/export-backend-ecs-artifact.sh` for retrieving profiles from ECS
2. Document script usage in lab guide
3. Test script against dev environment

**Phase 4: Documentation Enhancements**
1. Add architecture diagram showing lab flow
2. Add screenshots of Chrome DevTools analysis
3. Add example flamegraph interpretation
4. Create interview talking points for lab demonstration

**Phase 5: Deployment**
1. Deploy to dev environment with LAB_ENABLE=true
2. Test full lab workflow end-to-end
3. Create Terraform variables for lab configuration
4. Document deployment considerations

---

## Session Summary (December 14-15, 2025)

**Accomplishments:**
- ✅ Phase 1 complete - Lab module code integrated (PR #67)
- ✅ Phase 2 complete - All 13 local tests passing (PR #68)
- ✅ Fixed TypeScript error in lab.service.ts
- ✅ Fixed Inspector source file visibility issue
- ✅ Added security warning comments per Gemini feedback
- ✅ Created comprehensive local testing guide (382 lines)

**Technical Learnings:**
- Flame chart interpretation (X-axis = time, Y-axis = call stack, width = CPU time)
- Heap snapshot comparison (use "Comparison" view, filter by Constructor name)
- NestJS debug mode vs NODE_OPTIONS for Inspector visibility

**Files Created:**
- `docs/labs/node-profiling-lab-local-testing.md` (382 lines)
- Updated `docker-compose.yml` with NestJS debug mode
- Updated `backend/src/lab/lab.service.ts` with TypeScript fix
