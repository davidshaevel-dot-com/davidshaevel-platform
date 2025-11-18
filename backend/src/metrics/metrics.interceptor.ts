import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { MetricsService } from './metrics.service';
import { Request, Response } from 'express';

@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  constructor(private readonly metricsService: MetricsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<Request>();
    // Express types request.route as any, so we need to explicitly type it
    const routePath = (request.route as { path?: string } | undefined)?.path;
    const route = routePath || request.url;

    // Skip recording metrics for the /api/metrics endpoint itself
    if (route.includes('/metrics')) {
      return next.handle();
    }

    const response = context.switchToHttp().getResponse<Response>();
    const startTime = Date.now();
    const method = request.method;

    return next.handle().pipe(
      tap({
        next: () => {
          const duration = (Date.now() - startTime) / 1000; // Convert to seconds
          const statusCode = response.statusCode;
          this.metricsService.recordHttpRequest(
            method,
            route,
            statusCode,
            duration,
          );
        },
        error: (error: Error & { status?: number }) => {
          const duration = (Date.now() - startTime) / 1000;
          const statusCode = error.status || 500;

          this.metricsService.recordHttpRequest(
            method,
            route,
            statusCode,
            duration,
          );
          this.metricsService.recordHttpError(
            method,
            route,
            statusCode,
            error.name || 'UnknownError',
          );
        },
      }),
    );
  }
}
