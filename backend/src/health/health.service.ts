import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

@Injectable()
export class HealthService {
  private startTime: Date = new Date();

  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}

  async check() {
    const now = new Date();
    const uptimeSeconds = (now.getTime() - this.startTime.getTime()) / 1000;

    let databaseStatus = 'disconnected';
    let databaseError: string | undefined;

    try {
      // Check database connection
      const result = await this.dataSource.query('SELECT 1');
      if (result) {
        databaseStatus = 'connected';
      }
    } catch (error) {
      databaseStatus = 'error';
      databaseError = error.message;
    }

    const isHealthy = databaseStatus === 'connected';

    const response = {
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: now.toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      service: 'backend',
      uptime: uptimeSeconds,
      environment: process.env.NODE_ENV || 'development',
      database: {
        status: databaseStatus,
        type: 'postgresql',
        ...(databaseError &&
          process.env.NODE_ENV === 'development' && { error: databaseError }),
      },
    };

    if (!isHealthy) {
      throw new ServiceUnavailableException(response);
    }

    return response;
  }
}

