# Node.js Profiling & Debugging Lab (Hands-On)

This lab walks through **profiling and debugging a real Node.js service** using the backend deployed in this repo (the NestJS API behind `davidshaevel.com`).

You will learn three approaches to debugging Node.js applications:

| Part | Approach | Best For |
|------|----------|----------|
| **Part 1** | Local Inspector (Chrome DevTools) | Development, learning, interactive debugging |
| **Part 2** | HTTP Endpoints (Production-safe) | Staging, production incidents, remote systems |
| **Part 3** | Remote Inspector (Advanced) | Deep debugging in non-prod containers |

### What You'll Practice

- **Breakpoint debugging** - Step through code, inspect variables
- **CPU profiling** - Identify hot paths and performance bottlenecks
- **Memory analysis** - Find leaks with heap snapshots and comparison
- **Event loop monitoring** - Detect blocking operations
- **Prometheus metrics correlation** - Validate fixes with operational signals

> **Safety Note:** The lab endpoints are **disabled by default**, require a **token**, and refuse to run in production unless explicitly allowed.

---

## Prerequisites

- **Docker & Docker Compose** installed
- **Chrome browser** (for DevTools debugging)
- **AWS CLI** + Session Manager plugin (for Part 2 & 3 with ECS)
- **Terraform** (for the export script to read cluster/service names)
- **Python 3** (for the export script's base64 decoding)
- Optional: [Speedscope](https://www.speedscope.app/) for flamegraph visualization

## What Already Exists in This Repo

- Backend metrics endpoint: `GET /api/metrics`
- Default Node.js metrics via `prom-client` (`collectDefaultMetrics`) in `backend/src/metrics/metrics.service.ts`
- Backend service health endpoint: `GET /api/health`
- Lab module: `backend/src/lab/` with controller, service, guard, and module

---

# Part 1: Local Development Debugging (Inspector)

This section teaches **interactive debugging** using Node.js Inspector and Chrome DevTools. This is the fastest way to debug during development.

## Step 1.1 — Start the Development Environment

Start the backend with Inspector enabled:

```bash
# From repository root
docker compose up -d db backend

# Verify backend is running
docker compose logs -f backend
```

The backend starts with `NODE_OPTIONS="--inspect=0.0.0.0:9229"`, exposing the Inspector on port 9229.

**Enable lab endpoints** for this session:

```bash
# Edit docker-compose.yml and set:
#   LAB_ENABLE: "true"
#   LAB_TOKEN: "dev-token-123"

# Restart backend
docker compose restart backend
```

Verify lab endpoints are enabled:

```bash
curl -sS -H "x-lab-token: dev-token-123" \
  http://localhost:3001/api/lab/status | jq
```

Expected: `labEnabled: true`

---

## Step 1.2 — Attach Chrome DevTools

1. Open Chrome and navigate to: `chrome://inspect`

2. Click **"Configure..."** and ensure `localhost:9229` is in the list

3. Under **Remote Target**, you should see your Node.js process

4. Click **"inspect"** to open DevTools

You now have a live debugging session connected to your backend!

### DevTools Panels Overview

| Panel | Purpose |
|-------|---------|
| **Console** | Execute code in the running process |
| **Sources** | Set breakpoints, step through code |
| **Memory** | Take heap snapshots, find memory leaks |
| **Performance** | Record CPU profiles, analyze execution |
| **Profiler** | Detailed CPU sampling |

---

## Step 1.3 — Breakpoint Debugging

Learn to step through code and inspect state.

### Set a Breakpoint

1. In DevTools, go to **Sources** panel

2. Navigate to: `backend/src/lab/lab.controller.ts`
   - Use `Cmd+P` (Mac) or `Ctrl+P` (Windows) to open file picker
   - Type `lab.controller` to find the file

3. Find the `eventLoopJam` method (~line 24)

4. Click the line number to set a breakpoint (blue marker appears)

### Trigger the Breakpoint

```bash
curl -X POST -H "x-lab-token: dev-token-123" \
  "http://localhost:3001/api/lab/event-loop-jam?ms=1000"
```

The request will pause at your breakpoint!

### Debugging Controls

| Control | Shortcut | Action |
|---------|----------|--------|
| Resume | `F8` | Continue execution |
| Step Over | `F10` | Execute current line, move to next |
| Step Into | `F11` | Enter function call |
| Step Out | `Shift+F11` | Exit current function |

### Inspect State

While paused:

1. **Scope panel** - View local variables (`ms`, `this`)
2. **Watch panel** - Add expressions to monitor (e.g., `this.labService`)
3. **Call Stack** - See how you got here
4. **Console** - Evaluate expressions in current context

Try in Console while paused:
```javascript
this.labService.getStatus()
```

---

## Step 1.4 — Live CPU Profiling

Compare live profiling to the file-based approach in Part 2.

### Record a CPU Profile

1. In DevTools, go to **Performance** panel (or **Profiler** for detailed view)

2. Click the **Record** button (circle icon)

3. Trigger CPU-intensive work:
   ```bash
   curl -X POST -H "x-lab-token: dev-token-123" \
     "http://localhost:3001/api/lab/event-loop-jam?ms=3000"
   ```

4. Wait for the request to complete

5. Click **Stop** to end recording

### Analyze the Profile

The flamegraph shows:

- **X-axis:** Time during recording
- **Y-axis:** Call stack depth (bottom = entry point, top = leaf functions)
- **Width:** Time spent in each function

**What to look for:**

| Pattern | Indicates |
|---------|-----------|
| Wide bars at top | Hot functions (optimization targets) |
| Deep stacks | Complex call chains |
| Flat tops | Leaf functions doing heavy work |
| Gaps | Idle time (I/O wait, timers) |

In our event-loop-jam, you'll see a wide bar for the busy-wait loop in `lab.service.ts`.

### Compare to File-Based (Part 2)

| Aspect | Live (Part 1) | File-Based (Part 2) |
|--------|---------------|---------------------|
| Setup | Attach DevTools | HTTP endpoint call |
| Analysis | Immediate | Export file first |
| Sharing | Screenshot/export | Send .cpuprofile file |
| Production | Requires Inspector port | Works without port exposure |

---

## Step 1.5 — Live Heap Inspection

Find memory leaks using heap snapshots.

### Establish Baseline

1. In DevTools, go to **Memory** panel

2. Select **"Heap snapshot"**

3. Click **"Take snapshot"**

This is your baseline - note the total size.

### Induce Memory Growth

```bash
# Retain 64MB
curl -X POST -H "x-lab-token: dev-token-123" \
  "http://localhost:3001/api/lab/memory-leak?mb=64"

# Retain another 64MB
curl -X POST -H "x-lab-token: dev-token-123" \
  "http://localhost:3001/api/lab/memory-leak?mb=64"
```

### Take Second Snapshot and Compare

1. Take another heap snapshot

2. In the snapshot dropdown, select **"Comparison"**

3. Compare against Snapshot 1

### Analyze Memory Growth

In Comparison view:

- **#New** - Objects created since baseline
- **#Deleted** - Objects garbage collected
- **#Delta** - Net change in object count
- **Size Delta** - Net change in bytes

**Finding the leak:**

1. Sort by **Size Delta** (descending)
2. Look for large allocations - you'll see `Buffer` or `ArrayBuffer`
3. Click to expand and see **Retainers** (what's keeping it alive)
4. Trace back to `LabService.retainedBuffers` array

### Dominator Tree View

Switch to **"Dominators"** view to answer: *"What objects are keeping the most memory alive?"*

The dominator tree shows object ownership - an object's dominator is the nearest object that, if removed, would allow the target to be garbage collected.

### Cleanup

```bash
curl -X POST -H "x-lab-token: dev-token-123" \
  http://localhost:3001/api/lab/memory-clear
```

Take a third snapshot to verify memory was released.

---

# Part 2: Production-Style Debugging (HTTP Endpoints)

When you can't attach Inspector directly (production, remote systems, security constraints), use the **token-protected HTTP endpoints** for profiling.

This approach is **production-safe** because:
- Endpoints are disabled by default (`LAB_ENABLE=false`)
- Token authentication required (`x-lab-token` header)
- Additional production guard (`LAB_ALLOW_PROD=true` required in production)
- No open debugging ports

---

## Step 2.0 — Confirm Baseline

Before enabling lab endpoints, establish baseline metrics:

1. Check API health:
   ```bash
   curl -sS https://davidshaevel.com/api/health | jq
   ```

2. Confirm metrics render:
   ```bash
   curl -sS https://davidshaevel.com/api/metrics | head -50
   ```

3. Record baseline signals:
   - p95/p99 latency (from your APM/ALB metrics, if available)
   - Backend CPU and memory (CloudWatch/ECS task metrics)
   - Prometheus Node metrics (CPU, heap, GC, event loop lag)

---

## Step 2.1 — Enable Lab Endpoints (Opt-in)

The lab endpoints are at `/api/lab/*` and are guarded by:
- `LAB_ENABLE=true`
- `LAB_TOKEN=<random secret>`
- In production, also requires `LAB_ALLOW_PROD=true`

### For ECS Deployment

Set environment variables in your task definition or Terraform:

```hcl
# terraform/modules/backend/variables.tf
variable "lab_enable" {
  description = "Enable lab endpoints (never in production without lab_allow_prod)"
  type        = bool
  default     = false
}

variable "lab_token" {
  description = "Secret token for lab endpoint authentication"
  type        = string
  sensitive   = true
  default     = ""
}
```

Suggested approach:
- Enable on a **temporary canary task** (recommended)
- Or enable briefly during a controlled window

### Verify Lab Status

```bash
export LAB_TOKEN="your-secret-token"

curl -sS -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/status | jq
```

Expected: `labEnabled: true`

---

## Step 2.2 — Reproduce an Event Loop Jam (CPU Stall)

Trigger a CPU jam (default 2000ms, max 60000ms):

```bash
curl -sS -X POST \
  -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/event-loop-jam?ms=5000" | jq
```

### What to Observe

| Metric | Where to Look | Expected Change |
|--------|---------------|-----------------|
| Request latency | ALB metrics, Prometheus | Spike to 5s+ |
| Other requests | Concurrent curl | Queue behind jam |
| CPU usage | ECS task metrics | Near 100% |
| Event loop lag | Prometheus `nodejs_eventloop_lag_*` | Spike |

**Try this:** In another terminal, make a health check request while the jam is running:

```bash
time curl -sS https://davidshaevel.com/api/health
```

You'll see it takes ~5 seconds because the event loop is blocked!

---

## Step 2.3 — Capture a CPU Profile (File-Based)

Capture a profile for 30 seconds (adjustable 1–120):

```bash
curl -sS -X POST \
  -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/cpu-profile?seconds=30" | jq
```

Response includes a `/tmp/... .cpuprofile` path on the running task.

### Export the Profile from ECS

Use the helper script to download the profile directly from the ECS container:

```bash
# From the repository root
cd /path/to/davidshaevel-platform

# Export the CPU profile (use the path from the curl response)
AWS_PROFILE=davidshaevel-dev ./scripts/export-backend-ecs-artifact.sh \
  "/tmp/cpu-2025-12-15T22-30-00.000Z.cpuprofile" \
  "./cpu-profile.cpuprofile"
```

The script:
1. Discovers the running backend task automatically via Terraform outputs
2. Uses ECS Exec to base64-encode the file inside the container
3. Extracts and decodes the payload locally
4. Writes the file to your specified output path

**Expected output:** `Wrote XXXXX bytes to ./cpu-profile.cpuprofile`

**Alternative: Manual Export via S3**

If the helper script doesn't work for your environment, you can export via S3:

```bash
# 1. Copy file to S3 from within the container (via ECS Exec)
aws ecs execute-command --cluster $CLUSTER --task $TASK_ID \
  --container backend --interactive \
  --command "aws s3 cp /tmp/<file>.cpuprofile s3://your-bucket/profiles/"

# 2. Download from S3 to local machine
aws s3 cp s3://your-bucket/profiles/<file>.cpuprofile ./cpu.cpuprofile
```

### Analyze the Profile

**Option A: Chrome DevTools**
1. Open DevTools → Performance
2. Click load icon → Select `cpu.cpuprofile`

**Option B: Speedscope**
1. Go to https://www.speedscope.app/
2. Drag and drop `cpu.cpuprofile`

### What You're Looking For

| Pattern | Possible Cause | Action |
|---------|---------------|--------|
| JSON.parse hot | Large payloads | Stream parsing, pagination |
| RegExp hot | Complex patterns | Simplify regex, precompile |
| Sync fs calls | File I/O blocking | Use async versions |
| ORM overhead | N+1 queries, hydration | Query optimization |
| Logging hot | Excessive logging | Reduce log level |

---

## Step 2.4 — Reproduce Memory Growth (Retained Heap)

Allocate and retain 64MB each call (adjustable 1–1024):

```bash
curl -sS -X POST \
  -H "x-lab-token: $LAB_TOKEN" \
  "https://davidshaevel.com/api/lab/memory-leak?mb=64" | jq
```

Repeat a few times, then check status:

```bash
curl -sS -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/status | jq
```

### What to Observe

| Metric | Where to Look | Expected Change |
|--------|---------------|-----------------|
| RSS | ECS task metrics | Steady increase |
| Heap used | Prometheus `nodejs_heap_size_used_bytes` | Increase by ~64MB each |
| Heap total | Prometheus `nodejs_heap_size_total_bytes` | May expand |
| GC frequency | Prometheus `nodejs_gc_*` | Increase (trying to free memory) |

---

## Step 2.5 — Capture Heap Snapshots (File-Based)

Create a heap snapshot:

```bash
curl -sS -X POST \
  -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/heap-snapshot | jq
```

Export it using the helper script:

```bash
# Export the heap snapshot (use the path from the curl response)
AWS_PROFILE=davidshaevel-dev ./scripts/export-backend-ecs-artifact.sh \
  "/tmp/heapdump-2025-12-15T22-35-00.000Z.heapsnapshot" \
  "./heap-snapshot.heapsnapshot"
```

> **Note:** Heap snapshots can be large (tens to hundreds of MB). The export may take 30-60 seconds depending on heap size.

**Alternative: Manual export via S3** (see [Export the Profile from ECS](#export-the-profile-from-ecs) for details)

### Analyze in Chrome

1. Open Chrome DevTools → **Memory** panel
2. Click **Load** and select your `.heapsnapshot` file
3. Explore with **Summary**, **Comparison**, and **Dominators** views

### Comparison Workflow (Two Snapshots)

1. Take baseline snapshot (before memory growth)
2. Induce memory growth
3. Take second snapshot
4. Load both in DevTools
5. Use **Comparison** view to see delta

---

## Step 2.6 — Cleanup

Clear retained memory:

```bash
curl -sS -X POST \
  -H "x-lab-token: $LAB_TOKEN" \
  https://davidshaevel.com/api/lab/memory-clear | jq
```

Disable lab endpoints by removing env vars or redeploying.

---

# Part 3: Remote Debugging (Advanced)

For deep debugging of containerized services when HTTP endpoints aren't enough, you can attach Chrome DevTools directly to a remote container using port forwarding.

> **Warning:** This exposes the Inspector protocol which has **no authentication**. Only use in non-production environments or with strict network controls.

---

## Step 3.1 — Prerequisites

- Container must start Node.js with `--inspect=0.0.0.0:9229`
- ECS Execute Command must be enabled on the service
- AWS Session Manager plugin installed locally

---

## Step 3.2 — Enable Inspector in ECS Task

Add to your task definition or Terraform:

```hcl
# Only for debugging sessions, not permanent!
environment = [
  {
    name  = "NODE_OPTIONS"
    value = "--inspect=0.0.0.0:9229"
  }
]
```

Redeploy the service.

---

## Step 3.3 — Port Forward via SSM

Find your task details:

```bash
# Get cluster ARN
CLUSTER="dev-davidshaevel-cluster"

# List running tasks
aws ecs list-tasks --cluster $CLUSTER --service backend

# Get task ID from the ARN
TASK_ID="abc123..."
```

Start port forwarding:

```bash
aws ssm start-session \
  --target "ecs:${CLUSTER}_${TASK_ID}_backend" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9229"],"localPortNumber":["9229"]}'
```

---

## Step 3.4 — Attach Chrome DevTools

With port forwarding active:

1. Open `chrome://inspect`
2. Ensure `localhost:9229` is configured
3. Your remote Node.js process should appear
4. Click **"inspect"** to debug

You now have full DevTools access to the remote container!

---

## Step 3.5 — Cleanup

1. Close the SSM session (`Ctrl+C`)
2. Remove `NODE_OPTIONS` from task definition
3. Redeploy service

---

# Appendix

## When to Use Each Approach

| Scenario | Recommended | Why |
|----------|-------------|-----|
| Local development | Part 1 (Inspector) | Fastest iteration, full DevTools |
| CI/CD debugging | Part 1 (Inspector) | Can attach to test containers |
| Staging investigation | Part 2 (HTTP) | Production-safe, no port exposure |
| Production incident | Part 2 (HTTP) | Token auth, controlled access |
| Deep debugging (non-prod) | Part 3 (Remote) | Full DevTools on live container |
| Performance baseline | Part 2 (HTTP) | Consistent, repeatable |

## Lab Endpoint Reference

| Endpoint | Method | Description | Parameters |
|----------|--------|-------------|------------|
| `/api/lab/status` | GET | Check lab status, retained memory | - |
| `/api/lab/event-loop-jam` | POST | Block event loop | `ms` (1-60000, default 2000) |
| `/api/lab/memory-leak` | POST | Retain memory buffer | `mb` (1-1024, default 64) |
| `/api/lab/memory-clear` | POST | Clear retained buffers | - |
| `/api/lab/heap-snapshot` | POST | Write heap snapshot | - |
| `/api/lab/cpu-profile` | POST | Capture CPU profile | `seconds` (1-120, default 30) |

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `LAB_ENABLE` | Enable lab endpoints | `false` |
| `LAB_TOKEN` | Authentication token | (none) |
| `LAB_ALLOW_PROD` | Allow in production | `false` |
| `NODE_OPTIONS` | Node.js flags (e.g., `--inspect`) | (none) |

## Troubleshooting

### Inspector not visible in chrome://inspect

1. Verify Node.js started with `--inspect` flag
2. Check port 9229 is exposed (Docker) or forwarded (SSM)
3. Ensure `localhost:9229` is in Chrome's target configuration
4. Try restarting Chrome

### Heap snapshot fails

1. Ensure `/tmp` is writable in container
2. Check available disk space
3. Large heaps may take minutes to snapshot

### CPU profile missing data

1. Ensure profiling ran for long enough (10s+ recommended)
2. Verify the operation occurred during profiling window
3. Check file was fully written before export

### Export script fails

1. **"could not find base64 payload"** - The file may not exist, or the task was replaced
   - Verify the file path matches exactly what the lab endpoint returned
   - Check if a new deployment replaced the task (artifacts are lost on task replacement)
   - Run the lab endpoint again to generate a fresh artifact

2. **"could not find a RUNNING task"** - No backend tasks are running
   - Check ECS service status: `aws ecs describe-services --cluster dev-davidshaevel-cluster --services dev-davidshaevel-backend`

3. **Terraform errors** - Script can't read outputs
   - Ensure you're in the correct directory or set `TF_ENV_DIR`
   - Run `terraform init` if needed

4. **SSM/ECS Exec errors** - Session Manager issues
   - Verify Session Manager plugin is installed: `session-manager-plugin --version`
   - Ensure `enable_backend_ecs_exec = true` in Terraform
   - Check IAM permissions for ECS Exec

5. **Multi-task deployment**: Profile on different task than script targets

   When running multiple backend tasks (high availability), curl requests are load-balanced across tasks. The profile may be created on a different task than the one the export script connects to.

   **Workaround**: List all running tasks and check each one for the artifact:

   ```bash
   # List all backend task ARNs
   AWS_PROFILE=davidshaevel-dev aws ecs list-tasks \
     --cluster dev-davidshaevel-cluster \
     --service-name dev-davidshaevel-backend \
     --query 'taskArns' --output text

   # Check each task for the file
   AWS_PROFILE=davidshaevel-dev aws ecs execute-command \
     --cluster dev-davidshaevel-cluster \
     --task <TASK_ARN> \
     --container backend \
     --interactive \
     --command "ls -la /tmp/*.cpuprofile /tmp/*.heapsnapshot 2>/dev/null || echo 'No artifacts'"
   ```

   Once you find the task with your artifact, use the `TASK_ARN` environment variable to specify it:

   ```bash
   TASK_ARN=<task-arn-with-artifact> AWS_PROFILE=davidshaevel-dev ./scripts/export-backend-ecs-artifact.sh \
     "/tmp/cpu-xxx.cpuprofile" "./cpu.cpuprofile"
   ```

6. **SSM session EOF**: Session terminates before output completes

   ECS Exec sessions may terminate with "Cannot perform start session: EOF" before the base64 output completes. This is a known limitation of SSM session streaming with larger outputs (even files as small as 10-15KB can trigger this).

   **Root cause**: The SSM session buffer/timeout limits cause the session to close before the full base64-encoded file can be transmitted.

   **Recommended workaround**: Use **remote debugging (Part 3)** instead of the export script. With Chrome DevTools connected via port forwarding:
   - Start a CPU profile directly from DevTools Performance tab
   - Save the profile locally with "Save profile..." button
   - No ECS Exec limitations since data flows through the Inspector protocol

   **Alternative workarounds**:
   - Try the export multiple times (session stability varies)
   - For very small files (<5KB), the export may succeed
   - Manually extract the partial base64 from the error output (if BEGIN marker is visible)

## Notes / Extensions

- If you want to practice "realistic" failures:
  - Add an unbounded cache keyed by user/route
  - Add accidental listener growth
  - Add large per-request buffer retention
- Best practice is to profile **one canary task** at a time

## Further Reading

- [Node.js Debugging Guide](https://nodejs.org/en/docs/guides/debugging-getting-started/)
- [Chrome DevTools Memory Panel](https://developer.chrome.com/docs/devtools/memory-problems/)
- [V8 CPU Profiler](https://v8.dev/docs/profile)
- [prom-client Documentation](https://github.com/siimon/prom-client)
