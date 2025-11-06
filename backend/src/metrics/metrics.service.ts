import { Injectable } from '@nestjs/common';

@Injectable()
export class MetricsService {
  private startTime: Date = new Date();

  getPrometheusMetrics(): string {
    const uptime = (Date.now() - this.startTime.getTime()) / 1000;
    const memoryUsage = process.memoryUsage();

    const metrics = [
      '# HELP backend_uptime_seconds Application uptime in seconds',
      '# TYPE backend_uptime_seconds counter',
      `backend_uptime_seconds ${uptime}`,
      '',
      '# HELP backend_info Backend application information',
      '# TYPE backend_info gauge',
      `backend_info{version="${process.env.npm_package_version || '1.0.0'}",environment="${process.env.APP_ENV || process.env.NODE_ENV || 'development'}"} 1`,
      '',
      '# HELP nodejs_memory_usage_bytes Node.js memory usage in bytes',
      '# TYPE nodejs_memory_usage_bytes gauge',
      `nodejs_memory_usage_bytes{type="rss"} ${memoryUsage.rss}`,
      `nodejs_memory_usage_bytes{type="heapTotal"} ${memoryUsage.heapTotal}`,
      `nodejs_memory_usage_bytes{type="heapUsed"} ${memoryUsage.heapUsed}`,
      `nodejs_memory_usage_bytes{type="external"} ${memoryUsage.external}`,
      '',
    ];

    return metrics.join('\n');
  }
}

