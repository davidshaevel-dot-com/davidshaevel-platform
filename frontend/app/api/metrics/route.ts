import { NextResponse } from 'next/server';

/**
 * Prometheus Metrics Endpoint
 * 
 * Returns basic Prometheus-compatible metrics for monitoring.
 * This endpoint will be scraped by Prometheus for observability.
 * 
 * @returns 200 OK with Prometheus metrics in text format
 */
export async function GET() {
  const metrics = `# HELP frontend_uptime_seconds Application uptime in seconds
# TYPE frontend_uptime_seconds counter
frontend_uptime_seconds ${process.uptime()}

# HELP frontend_info Frontend application information
# TYPE frontend_info gauge
frontend_info{version="${process.env.npm_package_version || '1.0.0'}",environment="${process.env.NODE_ENV || 'development'}"} 1

# HELP nodejs_memory_usage_bytes Node.js memory usage in bytes
# TYPE nodejs_memory_usage_bytes gauge
nodejs_memory_usage_bytes{type="rss"} ${process.memoryUsage().rss}
nodejs_memory_usage_bytes{type="heapTotal"} ${process.memoryUsage().heapTotal}
nodejs_memory_usage_bytes{type="heapUsed"} ${process.memoryUsage().heapUsed}
nodejs_memory_usage_bytes{type="external"} ${process.memoryUsage().external}
`;

  return new NextResponse(metrics, {
    status: 200,
    headers: {
      'Content-Type': 'text/plain; version=0.0.4; charset=utf-8',
    },
  });
}

