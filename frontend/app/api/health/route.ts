import { NextResponse } from 'next/server';

/**
 * Health Check Endpoint
 * 
 * Returns the health status of the frontend application.
 * This endpoint is used by AWS ALB for target health checks.
 * 
 * @returns 200 OK with health status JSON
 */
export async function GET() {
  const healthCheck = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    service: 'frontend',
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  };

  return NextResponse.json(healthCheck, { status: 200 });
}

