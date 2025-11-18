import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { MetricsService } from './metrics.service';

@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  constructor(private readonly metricsService: MetricsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const response = context.switchToHttp().getResponse();

    const startTime = Date.now();
    const method = request.method;
    const route = request.route?.path || request.url;

    return next.handle().pipe(
      tap({
        next: () => {
          const duration = (Date.now() - startTime) / 1000; // Convert to seconds
          const statusCode = response.statusCode;

          // Skip recording metrics for the /api/metrics endpoint itself
          if (!route.includes('/metrics')) {
            this.metricsService.recordHttpRequest(method, route, statusCode, duration);
          }
        },
        error: (error) => {
          const duration = (Date.now() - startTime) / 1000;
          const statusCode = error.status || 500;

          // Skip recording metrics for the /api/metrics endpoint itself
          if (!route.includes('/metrics')) {
            this.metricsService.recordHttpRequest(method, route, statusCode, duration);
            this.metricsService.recordHttpError(
              method,
              route,
              statusCode,
              error.name || 'UnknownError'
            );
          }
        },
      }),
    );
  }
}
