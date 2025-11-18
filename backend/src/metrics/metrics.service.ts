import { Injectable } from '@nestjs/common';
import { Registry, Counter, Histogram, Gauge, collectDefaultMetrics } from 'prom-client';

@Injectable()
export class MetricsService {
  private readonly registry: Registry;
  private readonly httpRequestDuration: Histogram;
  private readonly httpRequestTotal: Counter;
  private readonly httpRequestErrors: Counter;
  private readonly dbQueryDuration: Histogram;
  private readonly dbQueryTotal: Counter;
  private readonly dbQueryErrors: Counter;
  private readonly backendInfo: Gauge;
  private readonly startTime: Date = new Date();

  constructor() {
    // Create a new registry
    this.registry = new Registry();

    // Collect default Node.js metrics (CPU, memory, event loop, etc.)
    collectDefaultMetrics({ register: this.registry });

    // HTTP request duration histogram
    this.httpRequestDuration = new Histogram({
      name: 'http_request_duration_seconds',
      help: 'Duration of HTTP requests in seconds',
      labelNames: ['method', 'route', 'status_code'],
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2.5, 5, 10],
      registers: [this.registry],
    });

    // HTTP request counter
    this.httpRequestTotal = new Counter({
      name: 'http_requests_total',
      help: 'Total number of HTTP requests',
      labelNames: ['method', 'route', 'status_code'],
      registers: [this.registry],
    });

    // HTTP error counter
    this.httpRequestErrors = new Counter({
      name: 'http_request_errors_total',
      help: 'Total number of HTTP request errors',
      labelNames: ['method', 'route', 'status_code', 'error_type'],
      registers: [this.registry],
    });

    // Database query duration histogram
    this.dbQueryDuration = new Histogram({
      name: 'db_query_duration_seconds',
      help: 'Duration of database queries in seconds',
      labelNames: ['query_type', 'table'],
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2.5, 5],
      registers: [this.registry],
    });

    // Database query counter
    this.dbQueryTotal = new Counter({
      name: 'db_queries_total',
      help: 'Total number of database queries',
      labelNames: ['query_type', 'table'],
      registers: [this.registry],
    });

    // Database error counter
    this.dbQueryErrors = new Counter({
      name: 'db_query_errors_total',
      help: 'Total number of database query errors',
      labelNames: ['query_type', 'table', 'error_type'],
      registers: [this.registry],
    });

    // Backend info gauge (custom metric to maintain compatibility)
    this.backendInfo = new Gauge({
      name: 'backend_info',
      help: 'Backend application information',
      labelNames: ['version', 'environment'],
      registers: [this.registry],
    });

    // Set backend info
    this.backendInfo.set(
      {
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.APP_ENV || process.env.NODE_ENV || 'development',
      },
      1
    );

    // Add custom uptime metric
    const uptimeGauge = new Gauge({
      name: 'backend_uptime_seconds',
      help: 'Application uptime in seconds',
      registers: [this.registry],
      collect: () => {
        const uptime = (Date.now() - this.startTime.getTime()) / 1000;
        uptimeGauge.set(uptime);
      },
    });
  }

  // Record HTTP request metrics
  recordHttpRequest(method: string, route: string, statusCode: number, duration: number) {
    this.httpRequestDuration.observe({ method, route, status_code: statusCode.toString() }, duration);
    this.httpRequestTotal.inc({ method, route, status_code: statusCode.toString() });
  }

  // Record HTTP error
  recordHttpError(method: string, route: string, statusCode: number, errorType: string) {
    this.httpRequestErrors.inc({ method, route, status_code: statusCode.toString(), error_type: errorType });
  }

  // Record database query metrics
  recordDbQuery(queryType: string, table: string, duration: number) {
    this.dbQueryDuration.observe({ query_type: queryType, table }, duration);
    this.dbQueryTotal.inc({ query_type: queryType, table });
  }

  // Record database error
  recordDbError(queryType: string, table: string, errorType: string) {
    this.dbQueryErrors.inc({ query_type: queryType, table, error_type: errorType });
  }

  // Get all metrics in Prometheus format
  async getPrometheusMetrics(): Promise<string> {
    return this.registry.metrics();
  }
}
