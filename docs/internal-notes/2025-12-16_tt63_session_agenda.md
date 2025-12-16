# TT-63 Node.js Profiling Lab - Session Agenda

**Date:** Tuesday, December 16, 2025
**Linear Issue:** [TT-63](https://linear.app/davidshaevel-dot-com/issue/TT-63/nodejs-profiling-and-debugging-hands-on-lab)
**Branch:** `david/tt-63-nodejs-profiling-debugging-hands-on-lab`
**Previous Session:** Part 3 Remote Debugging Complete (PR #71 merged)

---

## Session Goals

1. Update export script to use S3 instead of base64 encoding
2. Walk through all Part 2 steps to verify updated workflow
3. Create interview talking points and demo script
4. Complete TT-63

---

## Task 1: Update Export Script to Use S3 (Step 2.3)

### Problem Statement
The current `scripts/export-backend-ecs-artifact.sh` uses node.js inside the container to base64 encode files before outputting via SSM. This approach has limitations:
- Depends on node.js being available in container
- Subject to SSM session output limitations (EOF issues)
- Complex encoding/decoding workflow

### Solution
Update the helper script to:
1. Copy files to S3 from within the container
2. Download files from S3 to local machine
3. Clean up S3 artifacts after download

### Implementation Steps

#### 1.1 Read Current Export Script
```bash
cat scripts/export-backend-ecs-artifact.sh
```

#### 1.2 Update Script to Use S3
Key changes:
- Add S3 bucket configuration (use existing observability bucket or create new)
- Use `aws s3 cp` from within container to upload artifact
- Download from S3 to local machine
- Clean up S3 object after download

#### 1.3 Update Documentation (Step 2.3)
Update `docs/labs/node-profiling-and-debugging.md` to reflect new S3-based workflow:
- Update prerequisites (S3 bucket)
- Update export steps
- Update cleanup steps

---

## Task 2: Walk Through Part 2 Steps

### Prerequisites Verification
- [ ] ECS task running with lab endpoints enabled
- [ ] S3 bucket accessible from ECS task
- [ ] IAM permissions for S3 access from container

### Part 2 Steps to Execute

#### Step 2.1: Trigger Event Loop Jam
```bash
curl -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/event-loop-jam?ms=1000"
```

#### Step 2.2: Capture CPU Profile
```bash
curl -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/cpu-profile?seconds=5"
```

#### Step 2.3: Export CPU Profile (NEW S3 WORKFLOW)
```bash
./scripts/export-backend-ecs-artifact.sh /tmp/profile.cpuprofile ./profile.cpuprofile
```

#### Step 2.4: Trigger Memory Growth
```bash
curl -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/memory-growth?blocks=100"
```

#### Step 2.5: Capture Heap Snapshot
```bash
curl -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/heap-snapshot"
```

#### Step 2.6: Export Heap Snapshot (NEW S3 WORKFLOW)
```bash
./scripts/export-backend-ecs-artifact.sh /tmp/snapshot.heapsnapshot ./snapshot.heapsnapshot
```

#### Step 2.7: Analyze in Chrome DevTools
- Open Chrome DevTools → Memory tab → Load both files
- Compare heap snapshots to identify retained objects

### Verification Checklist
- [ ] CPU profile exports successfully via S3
- [ ] Heap snapshot exports successfully via S3
- [ ] Files can be loaded in Chrome DevTools
- [ ] S3 cleanup works correctly
- [ ] Documentation matches actual workflow

---

## Task 3: Interview Talking Points and Demo Script

### Talking Points Document
Create `docs/labs/node-profiling-interview-talking-points.md` covering:

#### Core Competencies Demonstrated
1. **Production Debugging Skills**
   - Remote debugging containerized Node.js services
   - Non-invasive profiling without service restart
   - Safe debugging in production environments

2. **V8 Engine Understanding**
   - Event loop mechanics and blocking operations
   - Heap structure and garbage collection
   - Memory leak identification

3. **AWS Infrastructure Integration**
   - ECS Exec for container access
   - SSM port forwarding for secure tunnels
   - S3 for artifact storage

4. **Chrome DevTools Proficiency**
   - CPU profiling and flame chart interpretation
   - Heap snapshot comparison
   - Retainer analysis for memory leaks

#### STAR Stories
1. **Situation:** Production service experiencing intermittent high latency
2. **Task:** Identify root cause without service disruption
3. **Action:** Used remote CPU profiling to capture flame charts
4. **Result:** Identified blocking regex operation, fixed with async pattern

### Demo Script
Create `docs/labs/node-profiling-demo-script.md` with:

#### Demo 1: Event Loop Blocking (3 minutes)
1. Show healthy Prometheus metrics
2. Trigger event loop jam
3. Observe metrics degradation
4. Capture CPU profile
5. Analyze flame chart

#### Demo 2: Memory Leak Detection (3 minutes)
1. Show baseline heap size
2. Trigger memory growth
3. Capture heap snapshots (before/after)
4. Use comparison view to identify leaked objects
5. Show retainer chain

#### Demo 3: Live Remote Debugging (3 minutes)
1. Enable Inspector via Terraform
2. Connect Chrome DevTools
3. Set breakpoint
4. Trigger request
5. Step through code

---

## Task 4: Finalize TT-63

### PR Creation
- Create PR with all changes
- Include comprehensive PR description
- Reference all completed work

### Linear Issue Update
- Mark all tasks complete
- Add final session summary comment
- Move to Done status

### Documentation Review
- Ensure all steps are accurate
- Verify all file paths correct
- Confirm all commands work

---

## Time Estimates

| Task | Estimated Time |
|------|----------------|
| Update export script | 30-45 minutes |
| Walk through Part 2 | 30-45 minutes |
| Interview talking points | 30-45 minutes |
| Demo script | 30-45 minutes |
| Finalize TT-63 | 15-30 minutes |
| **Total** | **2.5-3.5 hours** |

---

## Success Criteria

1. Export script uses S3 instead of base64 encoding
2. All Part 2 steps work correctly with new export method
3. Interview talking points document created
4. Demo script document created
5. TT-63 marked as Done in Linear
6. PR merged with all changes
