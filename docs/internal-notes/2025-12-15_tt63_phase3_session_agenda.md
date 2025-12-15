# TT-63: Node.js Profiling Lab - Phase 3 Session Agenda

**Date:** Monday, December 15, 2025
**Linear Issue:** [TT-63](https://linear.app/davidshaevel-dot-com/issue/TT-63/nodejs-profiling-debugging-hands-on-lab)
**Previous Session:** Phase 2 Local Testing Complete (PR #68 merged)
**Current Phase:** Phase 3 - Helper Scripts

---

## Session Overview

Continue work on the Node.js Profiling & Debugging Hands-On Lab. Phase 1 (Code Integration) and Phase 2 (Local Testing) are complete. This session focuses on Phase 3 (Helper Scripts) for retrieving profiling artifacts from ECS containers.

---

## Current Status

| Phase | Status | PR |
|-------|--------|-----|
| Phase 1: Code Integration | ✅ Complete | #67 |
| Phase 2: Local Testing | ✅ Complete | #68 |
| Phase 3: Helper Scripts | ⏳ In Progress | TBD |
| Phase 4: Documentation Enhancements | ⏳ Pending | - |
| Phase 5: Deployment | ⏳ Pending | - |

---

## Goals for This Session

### Primary Goal: Phase 3 - Helper Scripts

Create a helper script to retrieve CPU profiles and heap snapshots from ECS containers using ECS Exec.

**Script:** `scripts/export-backend-ecs-artifact.sh`

**Functionality:**
1. List available profile/snapshot files in container's `/tmp` directory
2. Download selected file to local machine
3. Support both CPU profiles (`.cpuprofile`) and heap snapshots (`.heapsnapshot`)
4. Handle ECS Exec session management

**Usage Example:**
```bash
# List available artifacts
./scripts/export-backend-ecs-artifact.sh --list

# Download a specific file
./scripts/export-backend-ecs-artifact.sh --download heapdump-2025-12-15T10-30-00.heapsnapshot

# Download most recent CPU profile
./scripts/export-backend-ecs-artifact.sh --download-latest cpu
```

---

## Task Breakdown

### Task 1: Create Export Script (60-90 min)

**File:** `scripts/export-backend-ecs-artifact.sh`

**Requirements:**
- [ ] AWS CLI and Session Manager plugin prerequisites check
- [ ] ECS cluster and service discovery (use existing patterns)
- [ ] List files in container `/tmp` matching `*.cpuprofile` and `*.heapsnapshot`
- [ ] Download file using `aws ecs execute-command` with cat/base64
- [ ] Error handling for common issues (no files, permission denied, etc.)
- [ ] Help text with usage examples

**Reference Scripts:**
- `scripts/test-prometheus-deployment.sh` - ECS Exec patterns
- `scripts/test-grafana-deployment.sh` - Task discovery patterns

### Task 2: Test Script Locally (30 min)

**Prerequisites:**
- Deploy lab module to dev environment (may need Phase 5 first)
- Generate test artifacts in container

**Test Cases:**
- [ ] `--help` displays usage
- [ ] `--list` shows files (or "no files" message)
- [ ] `--download` retrieves specific file
- [ ] `--download-latest cpu` retrieves most recent CPU profile
- [ ] `--download-latest heap` retrieves most recent heap snapshot
- [ ] Error handling for invalid file names

### Task 3: Update Lab Documentation (30 min)

**Update:** `docs/labs/node-profiling-and-debugging.md`

- [ ] Add section on retrieving artifacts from ECS
- [ ] Document script usage
- [ ] Add troubleshooting for common issues

---

## Stretch Goals (If Time Permits)

### Phase 4 Preview: Documentation Enhancements

- [ ] Create architecture diagram showing lab data flow
- [ ] Add annotated screenshot of Chrome DevTools flame chart
- [ ] Write flamegraph interpretation guide

### Phase 5 Preview: Deployment Preparation

- [ ] Review Terraform variables needed for lab configuration
- [ ] Plan LAB_ENABLE/LAB_TOKEN deployment strategy

---

## Technical Notes

### ECS Exec Pattern

```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-backend \
  --query 'taskArns[0]' \
  --output text)

# Execute command
aws ecs execute-command \
  --cluster dev-davidshaevel-cluster \
  --task $TASK_ARN \
  --container backend \
  --interactive \
  --command "ls -la /tmp/*.cpuprofile /tmp/*.heapsnapshot 2>/dev/null || echo 'No profiling artifacts found'"
```

### File Transfer via Base64

Since ECS Exec doesn't support direct file copy, use base64 encoding:

```bash
# In container: encode file
base64 /tmp/profile.cpuprofile

# Locally: decode and save
aws ecs execute-command ... --command "base64 /tmp/profile.cpuprofile" | base64 -d > profile.cpuprofile
```

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `scripts/export-backend-ecs-artifact.sh` | Create | ECS artifact export script |
| `docs/labs/node-profiling-and-debugging.md` | Update | Add artifact retrieval section |
| Session summary | Create | End-of-session documentation |

---

## Success Criteria

- [ ] Script successfully lists artifacts in ECS container
- [ ] Script successfully downloads CPU profile
- [ ] Script successfully downloads heap snapshot
- [ ] Documentation updated with usage instructions
- [ ] PR created and reviewed

---

## Environment Setup

```bash
# Ensure AWS SSO login
aws sso login --profile davidshaevel-dev

# Navigate to project
cd /Users/dshaevel/workspace-ds/davidshaevel-platform

# Ensure on main branch with latest
git checkout main
git pull origin main

# Create feature branch
git checkout -b david/tt-63-phase3-helper-scripts

# Verify ECS Exec is working
AWS_PROFILE=davidshaevel-dev aws ecs list-tasks \
  --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-backend
```

---

## Notes from Previous Sessions

**Phase 2 Key Learnings:**
- NestJS debug mode required for proper Inspector source file visibility
- Layered security (LAB_ENABLE, LAB_TOKEN, LAB_ALLOW_PROD) provides adequate protection
- 13/13 tests passing validates all endpoint functionality

**Potential Blockers:**
- Lab module not yet deployed to dev environment (may need to do Phase 5 first)
- If no artifacts exist, may need to manually trigger via curl to generate test files

---

**Session Target:** 2-3 hours
**Agent:** Claude (Opus 4.5)
**Repository:** davidshaevel-platform
