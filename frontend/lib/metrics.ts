import { Registry, Counter, Histogram, Gauge, collectDefaultMetrics } from 'prom-client';

// Create a singleton registry for metrics
let registry: Registry | null = null;
let startTime: number | null = null;

// Metrics instances
let pageViews: Counter<string> | null = null;
let apiCalls: Counter<string> | null = null;
let apiDuration: Histogram<string> | null = null;
let frontendInfo: Gauge<string> | null = null;
let uptimeGauge: Gauge<string> | null = null;

/**
 * Initialize or get the metrics registry
 * This is a singleton pattern to ensure we only create one registry
 */
export function getMetricsRegistry(): Registry {
  if (registry) {
    return registry;
  }

  // Create new registry
  registry = new Registry();
  startTime = Date.now();

  // Collect default Node.js metrics (CPU, memory, event loop, etc.)
  collectDefaultMetrics({ register: registry });

  // Page views counter
  pageViews = new Counter({
    name: 'frontend_page_views_total',
    help: 'Total number of page views',
    labelNames: ['page', 'method'],
    registers: [registry],
  });

  // API calls counter
  apiCalls = new Counter({
    name: 'frontend_api_calls_total',
    help: 'Total number of API calls to backend',
    labelNames: ['endpoint', 'method', 'status_code'],
    registers: [registry],
  });

  // API call duration histogram
  apiDuration = new Histogram({
    name: 'frontend_api_call_duration_seconds',
    help: 'Duration of API calls to backend in seconds',
    labelNames: ['endpoint', 'method'],
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2.5, 5, 10],
    registers: [registry],
  });

  // Frontend info gauge
  frontendInfo = new Gauge({
    name: 'frontend_info',
    help: 'Frontend application information',
    labelNames: ['version', 'environment'],
    registers: [registry],
  });

  // Set frontend info
  frontendInfo.set(
    {
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.APP_ENV || process.env.NODE_ENV || 'development',
    },
    1
  );

  // Frontend uptime gauge
  uptimeGauge = new Gauge({
    name: 'frontend_uptime_seconds',
    help: 'Application uptime in seconds',
    registers: [registry],
    collect: () => {
      if (startTime && uptimeGauge) {
        const uptime = (Date.now() - startTime) / 1000;
        uptimeGauge.set(uptime);
      }
    },
  });

  return registry;
}

/**
 * Record a page view
 */
export function recordPageView(page: string, method: string = 'GET') {
  if (!pageViews) {
    getMetricsRegistry();
  }
  pageViews?.inc({ page, method });
}

/**
 * Record an API call
 */
export function recordApiCall(endpoint: string, method: string, statusCode: number, duration: number) {
  if (!apiCalls || !apiDuration) {
    getMetricsRegistry();
  }
  apiCalls?.inc({ endpoint, method, status_code: statusCode.toString() });
  apiDuration?.observe({ endpoint, method }, duration);
}

/**
 * Get all metrics in Prometheus format
 */
export async function getMetrics(): Promise<string> {
  const reg = getMetricsRegistry();
  return reg.metrics();
}
