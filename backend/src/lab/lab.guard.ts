import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Request } from 'express';

@Injectable()
export class LabGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request>();

    const enabled = (process.env.LAB_ENABLE ?? '').toLowerCase() === 'true';
    if (!enabled) return false;

    // Extra safety: require explicit opt-in for production.
    const isProd = (process.env.NODE_ENV ?? '').toLowerCase() === 'production';
    const allowProd = (process.env.LAB_ALLOW_PROD ?? '').toLowerCase() === 'true';
    if (isProd && !allowProd) return false;

    const expectedToken = process.env.LAB_TOKEN ?? '';
    if (!expectedToken) return false;

    const providedToken = req.header('x-lab-token') ?? '';
    return providedToken === expectedToken;
  }
}





