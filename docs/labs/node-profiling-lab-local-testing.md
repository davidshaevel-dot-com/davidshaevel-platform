# Node.js Profiling Lab - Local Testing Guide

**Date:** December 14, 2025
**Linear Issue:** [TT-63](https://linear.app/davidshaevel-dot-com/issue/TT-63/nodejs-profiling-debugging-hands-on-lab)
**Phase:** 2 - Local Testing

---

## Prerequisites

- Docker and Docker Compose installed
- Git repository cloned: `davidshaevel-platform`
- Terminal access

---

## 1. Start the Development Environment

### Start Services

```bash
cd /path/to/davidshaevel-platform

# Start database and backend (with Inspector enabled)
docker compose up -d db backend
```

### Verify Services are Running

```bash
docker compose ps
```

Expected output:
```
NAME                          STATUS
davidshaevel-platform-db-1       Up (healthy)
davidshaevel-platform-backend-1  Up
```

### Check Backend Logs

```bash
docker compose logs -f backend
```

Look for:
- `Debugger listening on ws://0.0.0.0:9229/...` (Inspector enabled)
- `Backend API running on port 3001`

---

## 2. Test Lab Endpoints

### Environment Setup

```bash
# Set the lab token (matches docker-compose.yml)
export LAB_TOKEN="dev-token-123"
export BASE_URL="http://localhost:3001"
```

### Test 1: Status Endpoint (No Auth Required Check)

First, verify that requests without token are rejected:

```bash
# Should return 403 Forbidden
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/lab/status"
```

**Expected:** HTTP 403 (lab is disabled or no token)

### Test 2: Status Endpoint (With Auth)

```bash
curl -s -H "x-lab-token: $LAB_TOKEN" "$BASE_URL/api/lab/status" | jq
```

**Expected Response:**
```json
{
  "labEnabled": true,
  "nodeEnv": "development",
  "appEnv": null,
  "retainedBufferCount": 0,
  "retainedBytes": 0,
  "cpuProfileInProgress": false
}
```

### Test 3: Event Loop Jam

```bash
# Jam for 1 second (1000ms)
curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/event-loop-jam?ms=1000" | jq
```

**Expected Response:**
```json
{
  "jammedMs": 1000,
  "result": <some number>
}
```

**Note:** The request should take ~1 second to complete (blocking).

### Test 4: Memory Leak (Retain Memory)

```bash
# Retain 64MB
curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/memory-leak?mb=64" | jq
```

**Expected Response:**
```json
{
  "labEnabled": true,
  "nodeEnv": "development",
  "appEnv": null,
  "retainedBufferCount": 1,
  "retainedBytes": 67108864,
  "cpuProfileInProgress": false
}
```

### Test 5: Check Status After Memory Leak

```bash
curl -s -H "x-lab-token: $LAB_TOKEN" "$BASE_URL/api/lab/status" | jq
```

Should show `retainedBufferCount: 1` and `retainedBytes: 67108864`.

### Test 6: Memory Clear

```bash
curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/memory-clear" | jq
```

**Expected Response:**
```json
{
  "labEnabled": true,
  "nodeEnv": "development",
  "appEnv": null,
  "retainedBufferCount": 0,
  "retainedBytes": 0,
  "cpuProfileInProgress": false
}
```

### Test 7: Heap Snapshot

```bash
curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/heap-snapshot" | jq
```

**Expected Response:**
```json
{
  "filePath": "/tmp/heap-2025-12-14T...-<random>.heapsnapshot"
}
```

**Verify the file was created:**
```bash
docker compose exec backend ls -la /tmp/*.heapsnapshot
```

### Test 8: CPU Profile (Short Duration)

```bash
# Capture for 5 seconds
curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/cpu-profile?seconds=5" | jq
```

**Expected Response:**
```json
{
  "filePath": "/tmp/cpu-2025-12-14T...-<random>.cpuprofile",
  "durationSeconds": 5
}
```

**Note:** Request takes ~5 seconds to complete.

**Verify the file was created:**
```bash
docker compose exec backend ls -la /tmp/*.cpuprofile
```

### Test 9: Concurrent CPU Profile (Should Fail)

While a CPU profile is running, try to start another:

```bash
# In one terminal, start a long profile
curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/cpu-profile?seconds=30" &

# Immediately try another (should get 409 Conflict)
sleep 1
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/cpu-profile?seconds=5"
```

**Expected:** HTTP 409 Conflict with message "CPU profile already in progress"

---

## 3. Test Chrome DevTools Inspector

### Attach Chrome DevTools

1. Open Chrome and navigate to: `chrome://inspect`
2. Click "Configure..." and ensure `localhost:9229` is in the list
3. Under "Remote Target", you should see the Node.js process
4. Click "inspect" to open DevTools

### Test Breakpoint Debugging

1. In DevTools, go to **Sources** panel
2. Press `Cmd+P` (Mac) or `Ctrl+P` (Windows)
3. Type `lab.controller` and select the file
4. Find the `eventLoopJam` method (~line 24)
5. Click the line number to set a breakpoint

6. Trigger the breakpoint:
```bash
curl -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/event-loop-jam?ms=1000"
```

7. The request should pause at your breakpoint in DevTools
8. Step through the code using F10 (step over) or F11 (step into)
9. Click the play button to continue execution

### Test Live CPU Profiling

1. In DevTools, go to **Performance** tab
2. Click the record button (circle icon)
3. Run some requests:
```bash
for i in {1..5}; do
  curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
    "$BASE_URL/api/lab/event-loop-jam?ms=100"
done
```
4. Stop recording
5. Analyze the flame chart - you should see the busy loop

### Test Live Heap Inspection

1. In DevTools, go to **Memory** tab
2. Select "Heap snapshot" and click "Take snapshot"
3. Induce memory growth:
```bash
curl -s -X POST -H "x-lab-token: $LAB_TOKEN" \
  "$BASE_URL/api/lab/memory-leak?mb=32"
```
4. Take another snapshot
5. Compare snapshots to see the retained Buffer objects

---

## 4. Cleanup

### Stop Services

```bash
docker compose down
```

### Remove Volumes (Optional)

```bash
docker compose down -v
```

---

## Test Results Summary

**Test Date:** December 14, 2025
**Environment:** Docker Compose (macOS)

| Test | Endpoint | Expected | Status |
|------|----------|----------|--------|
| 1 | GET /api/lab/status (no auth) | 403 | ✅ PASS |
| 2 | GET /api/lab/status (with auth) | 200 + JSON | ✅ PASS |
| 3 | POST /api/lab/event-loop-jam | 200 + blocks | ✅ PASS (1.057s) |
| 4 | POST /api/lab/memory-leak | 200 + retained | ✅ PASS (67108864 bytes) |
| 5 | GET /api/lab/status (after leak) | shows retained | ✅ PASS |
| 6 | POST /api/lab/memory-clear | 200 + cleared | ✅ PASS |
| 7 | POST /api/lab/heap-snapshot | 200 + file path | ✅ PASS (~27MB file) |
| 8 | POST /api/lab/cpu-profile | 200 + file path | ✅ PASS (5.224s) |
| 9 | POST /api/lab/cpu-profile (concurrent) | 409 Conflict | ✅ PASS |
| 10 | Chrome DevTools attach | Inspector connected | ⏳ Manual |
| 11 | Breakpoint debugging | Pauses at breakpoint | ⏳ Manual |
| 12 | Live CPU profiling | Shows flame chart | ⏳ Manual |
| 13 | Live heap inspection | Shows Buffer objects | ⏳ Manual |

**Automated Tests:** 9/9 PASS
**Manual Tests:** 4 (require Chrome DevTools interaction)

---

## Troubleshooting

### Backend won't start

```bash
# Check logs for errors
docker compose logs backend

# Rebuild if needed
docker compose build backend
docker compose up -d backend
```

### Inspector not showing in Chrome

1. Ensure port 9229 is exposed: `docker compose ps` should show `9229->9229`
2. Check backend logs for "Debugger listening on ws://..."
3. Refresh `chrome://inspect`

### Lab endpoints return 403

1. Verify `LAB_ENABLE=true` in docker-compose.yml
2. Verify token matches: `x-lab-token: dev-token-123`
3. Check backend logs for guard rejection reason

### Database connection errors

```bash
# Wait for db to be healthy
docker compose up -d db
sleep 10
docker compose up -d backend
```

---

## Next Steps

After local testing passes:
1. Create PR with test results documented
2. Deploy to dev environment with `LAB_ENABLE=true`
3. Test full lab workflow end-to-end in dev
4. Create Terraform variables for lab configuration
