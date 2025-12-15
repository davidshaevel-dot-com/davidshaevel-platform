# TT-63 Phase 2 Session Summary - December 14, 2025

**Date:** Sunday, December 14, 2025
**Linear Issue:** [TT-63](https://linear.app/davidshaevel-dot-com/issue/TT-63/nodejs-profiling-debugging-hands-on-lab)
**Branch:** `david/tt-63-phase2-local-testing`
**PR:** #68 (merged)
**Status:** ✅ Phase 2 Complete

---

## Session Overview

Completed Phase 2 (Local Testing) of the Node.js Profiling & Debugging Hands-On Lab. All 13 tests passed (9 automated + 4 manual Chrome DevTools tests). Fixed several technical issues discovered during testing and addressed Gemini Code Assist feedback.

---

## Accomplishments

### 1. Local Testing Complete (13/13 PASS)

**Automated Tests (9/9):**

| Test | Endpoint | Expected | Result |
|------|----------|----------|--------|
| 1 | GET /api/lab/status (no auth) | 403 Forbidden | ✅ PASS |
| 2 | GET /api/lab/status (with auth) | 200 + JSON | ✅ PASS |
| 3 | POST /api/lab/event-loop-jam | Blocks for duration | ✅ PASS (1.057s) |
| 4 | POST /api/lab/memory-leak | Retains memory | ✅ PASS (67108864 bytes) |
| 5 | GET /api/lab/status (after leak) | Shows retained | ✅ PASS |
| 6 | POST /api/lab/memory-clear | Clears memory | ✅ PASS |
| 7 | POST /api/lab/heap-snapshot | Creates file | ✅ PASS (~27MB) |
| 8 | POST /api/lab/cpu-profile | Captures profile | ✅ PASS (5.224s) |
| 9 | POST /api/lab/cpu-profile (concurrent) | 409 Conflict | ✅ PASS |

**Manual Chrome DevTools Tests (4/4):**

| Test | Description | Result |
|------|-------------|--------|
| 10 | Attach Chrome DevTools Inspector | ✅ PASS - Connected successfully |
| 11 | Breakpoint debugging | ✅ PASS - Pauses at breakpoint |
| 12 | Live CPU profiling | ✅ PASS - Flame chart visible |
| 13 | Live heap inspection | ✅ PASS - Buffer objects found |

### 2. Bug Fixes

**TypeScript Error in lab.service.ts:**
- Problem: Inspector callback type mismatch
- Fix: Changed callback signature to `(err: Error | null, result?: object)` and cast `result as T`

**Inspector Source Files Not Visible:**
- Problem: `NODE_OPTIONS="--inspect=..."` only affects npm wrapper process, not the actual NestJS application
- Root Cause: The npm process inherits the flag, but when it spawns the nest process, the nest process gets its own Inspector instance
- Fix: Changed docker-compose command to use NestJS debug mode directly:
  ```yaml
  command: ["npx", "nest", "start", "--debug", "0.0.0.0:9229", "--watch"]
  ```
- Verification: `curl -s http://localhost:9229/json/list | jq '.[].title'` shows `/app/dist/main` instead of `/usr/local/bin/npm`

### 3. Security Warning Comments (Gemini Feedback)

Added warning comments per Gemini Code Assist review:

```yaml
# Lab endpoints configuration (enabled for local development)
# WARNING: The token below is for local testing ONLY and is not secure.
# It must be replaced with a strong secret for any non-local environment.
LAB_ENABLE: "true"
LAB_TOKEN: "dev-token-123"
```

### 4. Documentation Created

**Local Testing Guide:** `docs/labs/node-profiling-lab-local-testing.md` (382 lines)
- Prerequisites and setup instructions
- All 13 test cases documented with expected results
- Troubleshooting section for Inspector visibility issue
- Chrome DevTools screenshots workflow

---

## Technical Learnings

### Flame Chart Interpretation

- **X-axis:** Time progression (left to right)
- **Y-axis:** Call stack depth (root at bottom, nested calls above)
- **Width:** CPU time spent in function (wider = more time)
- **Colors:** Different functions/modules distinguished by color
- **Usage:** Identify CPU bottlenecks by looking for wide bars

### Heap Snapshot Comparison

- **Take baseline:** Snapshot before memory-inducing operation
- **Induce memory:** Call the endpoint that allocates memory
- **Take second snapshot:** After memory allocation
- **Compare:** Use "Comparison" view in Chrome DevTools Memory tab
- **Filter:** By "Constructor name" to find specific object types (e.g., Buffer)
- **Retainers:** Panel shows GC root path explaining why objects aren't collected

### NestJS Debug Mode vs NODE_OPTIONS

| Approach | Command | Attaches To | Source Files Visible |
|----------|---------|-------------|---------------------|
| NODE_OPTIONS | `NODE_OPTIONS="--inspect=0.0.0.0:9229"` | npm wrapper | ❌ No (only npm scripts) |
| NestJS Debug | `npx nest start --debug 0.0.0.0:9229` | NestJS app | ✅ Yes (full app sources) |

---

## Gemini Code Assist Review Handling

### First Round (Agreed and Implemented)
- Comment #1: Add warning about insecure local token → ✅ Implemented
- Comment #2: Add warning about production use → ✅ Implemented

### Second Round (Declined with Explanation)
- Comment #3: Use environment variable substitution → ❌ Declined
- Comment #4: Use placeholder values like "change-me" → ❌ Declined

**Reasoning for Declining:**
1. This is a local development learning lab, not production code
2. Docker Compose environment variable syntax doesn't support shell-style substitution
3. Existing layered protection already sufficient (LAB_ENABLE, LAB_TOKEN, LAB_ALLOW_PROD)
4. Warning comments provide adequate documentation for security awareness
5. Friction of required configuration would impede learning experience

---

## Files Created/Modified

### New Files
- `docs/labs/node-profiling-lab-local-testing.md` (382 lines)

### Modified Files
- `docker-compose.yml` - NestJS debug mode, security warnings
- `backend/src/lab/lab.service.ts` - TypeScript fix for inspector callback

---

## PR Summary

**PR #68:** Phase 2 Local Testing Complete

**Commits:**
1. `docs: Add local testing guide` - Initial testing documentation
2. `test: Complete Phase 2 local testing` - Test execution and results
3. `fix: Use NestJS debug mode for proper Inspector source file access` - Critical bug fix
4. `docs: Mark all 13 local tests as PASS` - Final test results
5. `security: Add warnings about insecure local development token` - Gemini feedback

**Review:** Gemini Code Assist provided 4 comments across 2 rounds
- Round 1: 2 comments (both implemented)
- Round 2: 2 comments (both declined with explanation)

---

## Next Steps (Tomorrow - December 16, 2025)

**Phase 3: Helper Scripts**
1. Create `scripts/export-backend-ecs-artifact.sh` for retrieving profiles from ECS
2. Document script usage in lab guide
3. Test script against dev environment

**Phase 4: Documentation Enhancements**
1. Add architecture diagram showing lab flow
2. Add screenshots of Chrome DevTools analysis
3. Add example flamegraph interpretation

**Phase 5: Deployment**
1. Deploy to dev environment with LAB_ENABLE=true
2. Test full lab workflow end-to-end
3. Create Terraform variables for lab configuration

---

## Interview Talking Points Enabled

1. "I understand tradeoffs between interactive and file-based debugging"
2. "I know how to debug containerized Node.js services in AWS"
3. "I implement safety controls for debugging in production"
4. "I can demonstrate live profiling with Chrome DevTools"
5. "I can explain V8 heap structure and garbage collection"
6. "I've worked through debugging Inspector attachment issues in Docker"

---

**Session Duration:** ~4 hours
**Agent:** Claude (Opus 4.5)
**Repository:** davidshaevel-platform
