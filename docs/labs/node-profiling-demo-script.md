# Node.js Profiling Lab - Demo Script

This script provides step-by-step instructions for demonstrating the Node.js profiling lab capabilities during interviews or presentations.

**Total Demo Time:** ~10 minutes (3 demos)

---

## Prerequisites

Before starting the demo, ensure:

1. **Lab endpoints enabled:**
   ```bash
   # In terraform.tfvars
   lab_enable = true
   lab_token  = "your-token"
   ```

2. **Profiling artifacts bucket enabled:**
   ```bash
   enable_profiling_artifacts_bucket = true
   ```

3. **Set environment variable:**
   ```bash
   export LAB_TOKEN="your-token"
   ```

4. **Have these tabs open:**
   - Terminal for commands
   - Chrome DevTools (or Speedscope)
   - Grafana dashboard (optional, for metrics visualization)

---

## Demo 1: Event Loop Blocking (~3 minutes)

### Objective
Show how to identify and analyze CPU-blocking operations.

### Script

**Step 1: Show healthy baseline (30 seconds)**
```bash
# Check API health
curl -sS https://davidshaevel.com/api/health | jq

# Check lab status
curl -sS -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/status | jq
```

**Talking point:** "The service is healthy. Let's see what happens when we block the event loop."

**Step 2: Trigger event loop jam (1 minute)**
```bash
# This will block the event loop for 3 seconds
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/event-loop-jam?ms=3000" | jq
```

**Talking point:** "Notice the response took ~3 seconds. During this time, ALL other requests to this task would be blocked. This is what happens when you have synchronous operations in Node.js."

**Step 3: Capture CPU profile (1 minute)**

In **Terminal 1**, start the profile capture:
```bash
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/cpu-profile?seconds=15" | jq
# Note the file path in the response
```

In **Terminal 2**, trigger activity while the profile is capturing:
```bash
# Run multiple jams to increase odds of hitting the same task
for i in {1..3}; do
  curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
    "https://davidshaevel.com/api/lab/event-loop-jam?ms=3000" | jq
done
```

**Talking point:** "The profile captures what the process is doing. Without triggering activity, we'd see an empty flame chart."

**Step 4: Export and analyze (30 seconds)**
```bash
# Export the profile
./scripts/export-backend-ecs-artifact.sh \
  "/tmp/<profile-path>.cpuprofile" \
  "$HOME/Downloads/demo-profile.cpuprofile"
```

**Step 5: Show in DevTools**
1. Open Chrome DevTools → Performance
2. Click Load → Select `demo-profile.cpuprofile` from your Downloads folder
3. Point out: "See this wide bar? That's our blocking operation. The width represents time."

---

## Demo 2: Memory Leak Detection (~3 minutes)

### Objective
Show how to identify memory leaks using heap snapshots.

### Script

**Step 1: Check baseline memory (30 seconds)**
```bash
curl -sS -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/status | jq
```

**Talking point:** "Currently no retained buffers. Let's intentionally leak some memory."

**Step 2: Take baseline snapshot (30 seconds)**
```bash
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/heap-snapshot | jq

# Export it
./scripts/export-backend-ecs-artifact.sh \
  "/tmp/<snapshot-path>.heapsnapshot" \
  "$HOME/Downloads/baseline.heapsnapshot"
```

**Step 3: Trigger memory growth (30 seconds)**
```bash
# Allocate and retain 256MB
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/memory-leak?mb=256" | jq

# Check status - should show retained buffers
curl -sS -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/status | jq
```

**Talking point:** "Now we have 256MB retained. This simulates a cache that grows unbounded."

**Step 4: Take second snapshot (30 seconds)**
```bash
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/heap-snapshot | jq

./scripts/export-backend-ecs-artifact.sh \
  "/tmp/<snapshot-path>.heapsnapshot" \
  "$HOME/Downloads/after-leak.heapsnapshot"
```

**Step 5: Compare in DevTools (1 minute)**
1. Open Chrome DevTools → Memory
2. Load both snapshots
3. Select "Comparison" view
4. Filter by "Buffer" or "ArrayBuffer"
5. Show: "These 32MB of Buffers appeared between snapshots - this is our leak."

**Step 6: Cleanup**
```bash
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/memory-clear | jq
```

---

## Demo 3: Remote Debugging with Inspector (~4 minutes)

### Objective
Show live remote debugging with breakpoints.

### Prerequisites
- Inspector enabled: `enable_backend_inspector = true`
- Terraform applied and service redeployed

### Script

**Step 1: Enable Inspector (if not already)**
```bash
# In terraform.tfvars
enable_backend_inspector = true

# Apply and deploy
terraform apply
aws ecs update-service ... --force-new-deployment
```

**Step 2: Get container runtime ID (30 seconds)**
```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster dev-davidshaevel-cluster \
  --service-name dev-davidshaevel-backend \
  --query 'taskArns[0]' --output text)

TASK_ID=$(basename "$TASK_ARN")

# Get runtime ID
RUNTIME_ID=$(aws ecs describe-tasks --cluster dev-davidshaevel-cluster \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[?name==`backend`].runtimeId' --output text)

echo "Target: ecs:dev-davidshaevel-cluster_${TASK_ID}_${RUNTIME_ID}"
```

**Step 3: Start port forwarding (30 seconds)**
```bash
aws ssm start-session \
  --target "ecs:dev-davidshaevel-cluster_${TASK_ID}_${RUNTIME_ID}" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9229"],"localPortNumber":["9229"]}'
```

**Step 4: Connect Chrome DevTools (1 minute)**
1. Open `chrome://inspect`
2. Click "Configure" → Add `localhost:9229`
3. Wait for target to appear
4. Click "inspect"

**Step 5: Set breakpoint and trigger (1 minute)**
1. Navigate to Sources → `file:///app/dist/lab/lab.controller.js`
2. Set breakpoint on line 27 (eventLoopJam method)
3. In another terminal:
   ```bash
   curl -X POST -H "x-lab-token: $LAB_TOKEN" \
     "https://davidshaevel.com/api/lab/event-loop-jam?ms=1000"
   ```
4. Show: "Execution paused at our breakpoint. We can inspect variables, step through code."

**Step 6: Step through and resume**
1. Show call stack
2. Show scope variables
3. Click Resume

**Talking point:** "This is powerful for debugging issues that only occur in production. We can step through code, inspect state, all without redeploying."

**Step 7: Cleanup**
```bash
# Disable Inspector
enable_backend_inspector = false
terraform apply
```

---

## Quick Reference Commands

```bash
# Lab status
curl -sS -H "x-lab-token: $LAB_TOKEN" https://davidshaevel.com/api/lab/status | jq

# Event loop jam (ms)
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/event-loop-jam?ms=1000" | jq

# CPU profile (seconds)
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/cpu-profile?seconds=10" | jq

# Memory leak (mb)
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/memory-leak?mb=256" | jq

# Heap snapshot
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/heap-snapshot | jq

# Clear memory
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/memory-clear | jq

# Export artifact
./scripts/export-backend-ecs-artifact.sh <container-path> <local-path>
```

---

## Troubleshooting During Demo

| Issue | Solution |
|-------|----------|
| 403 Forbidden | Check LAB_TOKEN is correct |
| Export fails | Check `enable_profiling_artifacts_bucket = true` |
| Inspector not connecting | Verify port forwarding is active |
| Profile file not found | Task may have been replaced; profile is on original task |
| "File does not exist" on export | Multi-task issue: artifact created on different task than export script connected to. Scale to 1 task or run multiple captures |
| Empty flame chart | No activity during capture. Trigger event loop jams or API traffic while profiling |

---

## Post-Demo Cleanup

```bash
# Clear retained memory
curl -sS -X POST -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/memory-clear | jq

# Remove local files
rm -f $HOME/Downloads/*.cpuprofile $HOME/Downloads/*.heapsnapshot

# Disable Inspector if enabled
# In terraform.tfvars: enable_backend_inspector = false
# terraform apply
```
