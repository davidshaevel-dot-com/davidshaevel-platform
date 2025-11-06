import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';

// Main application bootstrap
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const logger = new Logger('Bootstrap');
  
  // Enable CORS for frontend
  app.enableCors({
    origin:
      process.env.NODE_ENV === 'production'
        ? process.env.FRONTEND_URL || 'https://davidshaevel.com'
        : '*',
    credentials: true,
  });
  
  // Enable validation
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));
  
  // Set global prefix for API routes
  app.setGlobalPrefix('api');
  
  const port = process.env.PORT ?? 3001;
  await app.listen(port);
  logger.log(`🚀 Backend API running on port ${port}`);
}

bootstrap().catch((error: unknown) => {
  const logger = new Logger('Bootstrap');
  logger.error('Failed to start application', error);
  process.exit(1);
});
