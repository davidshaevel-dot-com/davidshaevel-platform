import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'node:crypto';
import { Request } from 'express';

@Injectable()
export class LabGuard implements CanActivate {
  constructor(private readonly configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request>();

    const enabled =
      this.configService.get<string>('LAB_ENABLE')?.toLowerCase() === 'true';
    if (!enabled) return false;

    // Extra safety: require explicit opt-in for production.
    const isProd =
      this.configService.get<string>('NODE_ENV')?.toLowerCase() === 'production';
    const allowProd =
      this.configService.get<string>('LAB_ALLOW_PROD')?.toLowerCase() === 'true';
    if (isProd && !allowProd) return false;

    const expectedToken = this.configService.get<string>('LAB_TOKEN');
    if (!expectedToken) return false;

    const providedToken = req.header('x-lab-token') ?? '';

    // Use constant-time comparison to prevent timing attacks.
    // Note: Length check is not constant-time, which can leak token length.
    // For this lab feature, this is an acceptable tradeoff.
    const expectedBuffer = Buffer.from(expectedToken);
    const providedBuffer = Buffer.from(providedToken);

    if (expectedBuffer.length !== providedBuffer.length) {
      return false;
    }

    return timingSafeEqual(expectedBuffer, providedBuffer);
  }
}





