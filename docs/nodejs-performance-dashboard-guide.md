# Node.js Performance Dashboard Guide

This guide explains how to read and interpret each panel in the **Node.js Performance** Grafana dashboard. Understanding these metrics is essential for diagnosing performance issues, memory leaks, and event loop blocking in Node.js applications.

## Dashboard Overview

The Node.js Performance dashboard provides real-time visibility into the runtime behavior of Node.js services. It uses metrics collected by `prom-client` via `collectDefaultMetrics()`.

**Access:** `https://grafana.davidshaevel.com` → Dashboards → Node.js Performance

**Service Selector:** Use the dropdown at the top to switch between `Backend` and `Frontend` services.

**Refresh Rate:** 30 seconds (configurable)

---

## Panel Reference

### Row 1: Memory Overview

#### 1. Heap Memory Usage (Top-left, 12-column width)

**Type:** Time series graph

**Metrics:**
- `nodejs_heap_size_used_bytes` — Current heap memory in use
- `nodejs_heap_size_total_bytes` — Total heap memory allocated by V8

**What it shows:**
- Two lines: "Heap Used" (actual memory consumption) and "Heap Total" (memory allocated from OS)
- The gap between them represents available headroom before V8 requests more memory

**How to interpret:**

| Pattern | Meaning | Action |
|---------|---------|--------|
| Heap Used grows steadily without dropping | **Memory leak** — objects are being retained | Capture heap snapshot, analyze retainers |
| Heap Used oscillates in sawtooth pattern | **Normal GC behavior** — memory is being reclaimed | No action needed |
| Heap Total keeps growing | V8 is requesting more memory from OS | Check if leak or legitimate growth |
| Heap Used approaches Heap Total | **Memory pressure** — GC running frequently | Investigate memory usage, increase container limits |

**During lab exercises:**
- After calling `/api/lab/memory-leak?mb=64` multiple times, you'll see Heap Used step up
- After calling `/api/lab/memory-clear`, you should see Heap Used drop (after next GC)

---

#### 2. Heap Usage Percentage (Top-center, gauge)

**Type:** Gauge (0-100%)

**Metric:**
```promql
100 * nodejs_heap_size_used_bytes / nodejs_heap_size_total_bytes
```

**What it shows:**
- How much of the allocated heap is currently in use

**Thresholds:**
| Color | Range | Meaning |
|-------|-------|---------|
| Green | 0-70% | Healthy — plenty of headroom |
| Yellow | 70-85% | Warning — GC working harder |
| Red | 85-100% | Critical — near OOM, GC thrashing likely |

**How to interpret:**
- Sustained red indicates the application needs more memory or has a leak
- Brief spikes into yellow during heavy load are normal
- If it stays red and the application slows down, you're experiencing GC thrashing

---

#### 3. External Memory (Top-right, upper stat)

**Type:** Stat panel

**Metric:** `nodejs_external_memory_bytes`

**What it shows:**
- Memory used by C++ objects bound to JavaScript objects (Buffers, native modules)
- This memory is outside the V8 heap but still tracked

**How to interpret:**

| Value | Meaning |
|-------|---------|
| Low/stable | Normal — typical for API services |
| High | Heavy use of Buffers, streams, or native modules |
| Growing steadily | Possible leak in Buffer handling or native bindings |

**Common causes of high external memory:**
- Large file uploads/downloads held in memory
- Image processing (sharp, jimp)
- Native database drivers with connection pooling
- Crypto operations

---

#### 4. Process Resident Memory (Top-right, lower stat)

**Type:** Stat panel

**Metric:** `process_resident_memory_bytes`

**What it shows:**
- Total memory the OS has allocated to the Node.js process (RSS)
- Includes: heap, external, native code, stack, shared libraries

**How to interpret:**

| Relationship | Meaning |
|--------------|---------|
| RSS ≈ Heap Total + External + overhead | Normal |
| RSS >> Heap Total | Native memory usage (C++ addons, buffers) |
| RSS growing when heap stable | Native memory leak or fragmentation |

**Why RSS matters:**
- This is what container memory limits see
- OOM killer uses RSS, not heap size
- If RSS hits container limit, process is killed

**During lab exercises:**
- RSS will grow after `/api/lab/memory-leak` calls
- RSS may not shrink immediately after clear (OS memory management)

---

### Row 2: Event Loop Health

#### 5. Event Loop Lag (Left, 12-column width)

**Type:** Time series graph

**Metrics:**
- `nodejs_eventloop_lag_seconds` — Current event loop lag
- `nodejs_eventloop_lag_mean_seconds` — Mean lag over time

**What it shows:**
- How long callbacks must wait before the event loop can process them
- The "heartbeat" of your Node.js application

**Thresholds:**
| Color | Lag | Meaning |
|-------|-----|---------|
| Green | < 100ms | Healthy — responsive |
| Yellow | 100-500ms | Warning — noticeable delays |
| Red | > 500ms | Critical — poor user experience |

**How to interpret:**

| Pattern | Meaning | Action |
|---------|---------|--------|
| Flat line near 0 | Healthy event loop | None needed |
| Spikes during requests | Synchronous work blocking | Profile CPU, find blocking code |
| Sustained elevation | Continuous blocking or overload | Scale horizontally, optimize code |
| Correlates with CPU spikes | CPU-bound work | Offload to worker threads |

**During lab exercises:**
- After calling `/api/lab/event-loop-jam?ms=5000`, you'll see a 5-second spike
- Other requests during the jam will queue, increasing their latency

---

#### 6. Event Loop Lag Percentiles (Right, 12-column width)

**Type:** Time series graph

**Metrics:**
- `nodejs_eventloop_lag_p50_seconds` — 50th percentile (median)
- `nodejs_eventloop_lag_p90_seconds` — 90th percentile
- `nodejs_eventloop_lag_p99_seconds` — 99th percentile

**What it shows:**
- Distribution of event loop lag over time
- p99 captures worst-case scenarios affecting 1% of event loop iterations

**How to interpret:**

| Percentile | Healthy Value | What it tells you |
|------------|---------------|-------------------|
| p50 | < 10ms | Typical request experience |
| p90 | < 50ms | Most users' experience |
| p99 | < 100ms | Worst 1% of delays |

**Red flags:**
- Large gap between p50 and p99 → intermittent blocking
- p99 spikes not matching p50 → occasional long-running sync operations
- All percentiles elevated → sustained overload

**Why percentiles matter:**
- Mean hides outliers
- p99 catches the "once in 100 requests" issues users complain about
- SLOs are often defined at p99 or p95

---

### Row 3: Resources and GC

#### 7. Active Handles & Requests (Left, 12-column width)

**Type:** Time series graph

**Metrics:**
- `nodejs_active_handles_total` — Open handles (sockets, timers, etc.)
- `nodejs_active_requests_total` — Pending async operations

**What it shows:**
- **Handles:** Long-lived resources (TCP connections, file descriptors, timers, child processes)
- **Requests:** Short-lived async operations (DNS lookups, file reads)

**How to interpret:**

| Pattern | Meaning | Action |
|---------|---------|--------|
| Handles stable | Normal — connection pools, servers | None |
| Handles growing unbounded | **Handle leak** — not closing resources | Check for missing `.close()` calls |
| Handles drop to near zero | Server shutdown or crash | Check health |
| Requests spike during load | Normal — processing requests | None |
| Requests stay elevated | Slow I/O or blocked operations | Check database, network |

**Common handle leaks:**
- Unclosed database connections
- Forgotten timers (`setInterval` without `clearInterval`)
- Event listeners not removed
- File descriptors not closed

**Healthy baseline (typical API server):**
- Handles: 5-50 (HTTP server, DB pool, timers)
- Requests: 0-10 (fluctuates with load)

---

#### 8. GC Duration (Right, 12-column width)

**Type:** Time series graph

**Metric:**
```promql
rate(nodejs_gc_duration_seconds_sum[5m])
```

**What it shows:**
- Time spent in garbage collection per second, broken down by GC type
- `kind` label values: `minor` (Scavenge), `major` (Mark-Sweep), `incremental`, `weakcb`

**GC Types Explained:**

| Kind | V8 Name | What it does | Duration |
|------|---------|--------------|----------|
| `minor` | Scavenge | Collects young generation (new objects) | Fast (< 10ms) |
| `major` | Mark-Sweep | Full heap collection | Slow (50-200ms) |
| `incremental` | Incremental Marking | Background marking for major GC | Low impact |
| `weakcb` | Weak Callbacks | Cleans up weak references | Usually fast |

**How to interpret:**

| Pattern | Meaning | Action |
|---------|---------|--------|
| Mostly minor GC | Healthy — short-lived objects collected efficiently | None |
| Frequent major GC | Memory pressure or leak | Investigate memory growth |
| GC time > 10% of wall time | **GC thrashing** — severe performance impact | Add memory, fix leaks |
| Major GC correlates with latency spikes | Stop-the-world pauses affecting requests | Consider heap size tuning |

**Healthy targets:**
- Total GC time < 5% of wall clock time
- Major GC frequency: few per minute under normal load

---

### Row 4: CPU and System Info

#### 9. CPU Usage (Left, 12-column width)

**Type:** Time series graph

**Metrics:**
```promql
rate(process_cpu_user_seconds_total[5m])   -- User CPU
rate(process_cpu_system_seconds_total[5m]) -- System CPU
```

**What it shows:**
- **User CPU:** Time spent executing JavaScript code
- **System CPU:** Time spent in kernel (I/O, syscalls)

**Unit:** Ratio of CPU time (0.5 = 50% of one CPU core)

**How to interpret:**

| Pattern | Meaning | Action |
|---------|---------|--------|
| User CPU < 0.5 | Light load, plenty of headroom | None |
| User CPU approaching 1.0 | Saturating one core | Scale or optimize |
| System CPU high | Heavy I/O or syscalls | Check disk, network |
| User CPU spikes correlate with event loop lag | CPU-bound blocking | Profile, find hot code |

**During lab exercises:**
- `/api/lab/event-loop-jam` will cause a User CPU spike
- You'll see correlation with Event Loop Lag panel

**Why this matters:**
- Node.js is single-threaded for JavaScript execution
- User CPU > 1.0 is impossible for JS (libuv threads can add more)
- High user CPU + event loop lag = CPU-bound bottleneck

---

#### 10. Process Uptime (Center stat)

**Type:** Stat panel

**Metric:**
```promql
time() - process_start_time_seconds
```

**What it shows:**
- How long the Node.js process has been running

**How to interpret:**

| Value | Meaning |
|-------|---------|
| Increasing steadily | Healthy — process is stable |
| Resets frequently | Process crashes or restarts |
| Different values per instance | Rolling deployments or instability |

**Why it matters:**
- Memory leaks compound over uptime
- Short uptime may indicate OOM kills
- Compare to deployment timestamps

---

#### 11. Node.js Version (Right stat)

**Type:** Stat panel

**Metric:** `nodejs_version_info`

**What it shows:**
- The Node.js version running in the container

**Why it matters:**
- Verify expected version after deployments
- Different versions have different GC behavior
- Security: ensure you're on a supported LTS version

---

### Row 5: Heap Space Details

#### 12. Heap Space Usage by Type (Bottom-right, 12-column width)

**Type:** Stacked time series graph

**Metric:** `nodejs_heap_space_size_used_bytes`

**What it shows:**
- V8 heap broken down by space type
- Stacked to show contribution of each space

**V8 Heap Spaces Explained:**

| Space | Purpose | What grows it |
|-------|---------|---------------|
| `new_space` | Young generation — new objects | Object allocation |
| `old_space` | Long-lived objects (survived 2 GCs) | Retained objects, caches |
| `code_space` | Compiled JavaScript code | Unique functions, eval() |
| `map_space` | Object shapes (hidden classes) | Many object shapes |
| `large_object_space` | Objects > 500KB | Large arrays, buffers |

**How to interpret:**

| Pattern | Meaning | Action |
|---------|---------|--------|
| `old_space` growing steadily | Objects not being released | Heap snapshot, find retainers |
| `new_space` fully utilized | High allocation rate | Normal under load |
| `code_space` large | Many functions or dynamic code | Avoid eval, reduce function creation |
| `large_object_space` growing | Large objects retained | Check for large array/buffer leaks |

**Memory leak investigation:**
1. Watch which space is growing
2. If `old_space`: retained objects (common leak)
3. If `large_object_space`: large buffers or arrays
4. Take heap snapshot during growth for analysis

---

## Using the Dashboard for Troubleshooting

### Scenario 1: High Latency Reports

**Check these panels in order:**

1. **Event Loop Lag** — Is the event loop blocked?
2. **Event Loop Lag Percentiles** — Is it affecting p99?
3. **CPU Usage** — Is CPU saturated?
4. **GC Duration** — Is GC causing pauses?

**If event loop lag is high:**
- Correlates with CPU → CPU-bound blocking code
- No CPU correlation → Synchronous I/O or external service

### Scenario 2: Memory Alerts

**Check these panels in order:**

1. **Heap Usage Percentage** — How close to limit?
2. **Heap Memory Usage** — Is it growing or sawtoothing?
3. **Heap Space Usage by Type** — Which space is growing?
4. **GC Duration** — Is major GC increasing?
5. **Process Resident Memory** — Is RSS tracking heap?

**Investigation path:**
```
Growing old_space → Take heap snapshot → Find retainers
Growing RSS but not heap → Native memory issue
GC thrashing → Increase memory or fix leak
```

### Scenario 3: Process Restarts

**Check these panels:**

1. **Process Uptime** — Did it reset?
2. **Process Resident Memory** — Was it near container limit?
3. **Heap Usage Percentage** — Was it in red before restart?

**Common causes:**
- OOM kill (RSS hit container limit)
- Uncaught exception
- Health check failures

---

## Integration with Lab Exercises

This dashboard is designed to work with the [Node.js Profiling & Debugging Lab](../jobs-2025-q4/docs/labs/node-profiling-and-debugging.md).

### Lab → Dashboard Correlation

| Lab Exercise | Dashboard Panels to Watch |
|--------------|--------------------------|
| Event loop jam (`/api/lab/event-loop-jam`) | Event Loop Lag, CPU Usage, Event Loop Lag Percentiles |
| Memory leak (`/api/lab/memory-leak`) | Heap Memory Usage, Heap Usage %, Heap Space by Type |
| CPU profile capture | CPU Usage (verify load during capture) |
| Heap snapshot | Heap Memory Usage (verify growth before capture) |
| Memory clear (`/api/lab/memory-clear`) | Heap Memory Usage (verify drop after next GC) |

### Recommended Workflow

1. **Baseline:** Open dashboard, note current values
2. **Reproduce:** Execute lab command
3. **Observe:** Watch real-time changes in relevant panels
4. **Capture:** Take CPU profile or heap snapshot
5. **Analyze:** Use Chrome DevTools with captured artifacts
6. **Verify:** Confirm fix shows improvement in dashboard

---

## Quick Reference: Healthy vs Unhealthy

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| Heap Usage % | < 70% | 70-85% | > 85% |
| Event Loop Lag | < 100ms | 100-500ms | > 500ms |
| GC Time (% of wall) | < 5% | 5-10% | > 10% |
| User CPU | < 0.7 | 0.7-0.9 | > 0.9 |
| Active Handles | Stable | Slowly growing | Unbounded growth |

---

## References

- [Node.js Performance Timing API](https://nodejs.org/api/perf_hooks.html)
- [V8 Memory Terminology](https://v8.dev/blog/trash-talk)
- [prom-client Default Metrics](https://github.com/siimon/prom-client#default-metrics)
- [Chrome DevTools Memory Panel](https://developer.chrome.com/docs/devtools/memory-problems/)

---

**Document Version:** 1.0
**Last Updated:** December 13, 2025
**Related:** [Grafana README](../observability/grafana/README.md), [Observability Architecture](./observability-architecture.md)
