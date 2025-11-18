import { NextResponse } from 'next/server';
import { getMetrics } from '@/lib/metrics';

/**
 * Prometheus Metrics Endpoint
 *
 * Returns Prometheus-compatible metrics for monitoring using prom-client.
 * This endpoint will be scraped by Prometheus for observability.
 *
 * Metrics included:
 * - Default Node.js metrics (CPU, memory, event loop, etc.)
 * - frontend_page_views_total: Page view counter
 * - frontend_api_calls_total: Backend API call counter
 * - frontend_api_call_duration_seconds: API call latency histogram
 * - frontend_info: Application version and environment
 * - frontend_uptime_seconds: Application uptime
 *
 * @returns 200 OK with Prometheus metrics in text format
 */
export async function GET() {
  const metrics = await getMetrics();

  return new NextResponse(metrics, {
    status: 200,
    headers: {
      'Content-Type': 'text/plain; version=0.0.4; charset=utf-8',
    },
  });
}
