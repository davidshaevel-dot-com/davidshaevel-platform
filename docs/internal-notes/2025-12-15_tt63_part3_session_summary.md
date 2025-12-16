# TT-63 Node.js Profiling Lab - Part 3 Remote Debugging Session Summary

**Date:** Monday, December 15, 2025
**Duration:** ~4 hours
**Linear Issue:** [TT-63](https://linear.app/davidshaevel-dot-com/issue/TT-63/nodejs-profiling-and-debugging-hands-on-lab)
**Branch:** `david/tt-63-nodejs-profiling-debugging-hands-on-lab`

---

## Session Objectives

1. Complete Part 3 Remote Debugging documentation and testing
2. Enable Node.js Inspector via Terraform
3. Test breakpoint debugging, CPU profiling, and heap inspection
4. Address Gemini Code Assist feedback
5. Merge PR #71

---

## Completed Work

### PR #71 - Part 3 Remote Debugging with Inspector Support

**Files Changed:** 9 files, 637 insertions(+), 99 deletions(-)

#### Infrastructure Changes

| File | Change |
|------|--------|
| `terraform/modules/compute/main.tf` | Added `NODE_OPTIONS` environment variable for Inspector |
| `terraform/modules/compute/variables.tf` | Added `enable_backend_inspector` variable |
| `terraform/environments/dev/main.tf` | Pass-through for inspector variable |
| `terraform/environments/dev/variables.tf` | Variable definition |
| `backend/Dockerfile` | Changed HEALTHCHECK from `node -e` to `wget` |

#### Documentation Changes

**`docs/labs/node-profiling-and-debugging.md`** - Major Part 3 expansion:

| Step | Description |
|------|-------------|
| 3.1 | Enable Inspector via Terraform |
| 3.2 | Deploy with Inspector enabled |
| 3.3 | Get container runtime ID |
| 3.4 | Start SSM port forwarding |
| 3.5 | **Breakpoint debugging** - Set breakpoint at line 27 |
| 3.6 | **Live CPU profiling** - Record during event loop jam |
| 3.7 | **Live heap inspection** - Snapshots before/after memory growth |
| 3.8 | **Cleanup** - Disable Inspector and redeploy |

---

## Issues Discovered and Fixed

### 1. Breakpoint File Path
- **Issue:** Documentation had wrong file path for breakpoints
- **Fix:** Updated to `file:///app/dist/lab/lab.controller.js:27`

### 2. Log Group Name
- **Issue:** `ResourceNotFoundException` when tailing logs
- **Cause:** Log group name was `/ecs/dev-davidshaevel-backend`
- **Fix:** Corrected to `/ecs/dev-davidshaevel/backend`

### 3. Force Deployment
- **Issue:** `--force-new-deployment` alone didn't use new task definition revision
- **Fix:** Added `--task-definition dev-davidshaevel-backend` flag

### 4. ARN Parsing (Gemini Feedback)
- **Issue:** `rev | cut | rev` pattern is fragile and unquoted
- **Fix:** Changed to `basename "$TASK_ARN"` (POSIX standard, more readable)

---

## Technical Learnings

### Node.js Inspector Remote Debugging
- Inspector must bind to `0.0.0.0:9229` (not localhost) for container access
- SSM port forwarding provides secure tunnel without exposing port publicly
- Chrome DevTools connects via `chrome://inspect` → Configure → `localhost:9229`

### Container Runtime ID Format
```
ecs:<cluster>_<task-id>_<runtime-id>
```
Example: `ecs:dev-davidshaevel-cluster_abc123_def456-789`

### Health Check Considerations
- `node -e` health checks can interfere with Inspector
- `wget` is more reliable and independent of Node.js process state

---

## Pull Request Timeline

| PR | Status | Description |
|----|--------|-------------|
| #67 | Merged | Phase 1: Lab module code |
| #68 | Merged | Phase 2: Local testing |
| #69 | Merged | Part 1 & 2 documentation |
| #70 | Merged | Phase 3: Terraform + export script |
| #71 | Merged | Phase 4: Part 3 Remote Debugging |

---

## Linear Issue Update

TT-63 updated with:
- Status moved back to "In Progress" (was incorrectly set to Done)
- Comment added with comprehensive PR #71 details
- Description updated with completed tasks marked
- Remaining task: Interview talking points and demo script

---

## Tomorrow's Agenda (December 16, 2025)

### Priority 1: Update Export Script (Step 2.3)
- Change helper script to copy files to S3 instead of base64 encoding via node.js
- Eliminates dependency on node.js inside container for file transfer
- S3 provides more reliable artifact storage

### Priority 2: Verify Part 2 Workflow
- Walk through all Part 2 steps with updated export script
- Confirm CPU profile and heap snapshot export works correctly
- Test end-to-end ECS artifact retrieval

### Priority 3: Interview Preparation
- Create interview talking points document
- Create demo script for live demonstrations
- Finalize TT-63

---

## Session Statistics

- **PRs Merged Today:** 1 (#71)
- **Files Changed:** 9
- **Lines Added:** 637
- **Lines Removed:** 99
- **Gemini Comments Addressed:** 1 (ARN parsing)
- **Documentation Steps Added:** 4 (Steps 3.5-3.8)
