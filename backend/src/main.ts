import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Enable CORS for frontend
  app.enableCors();
  
  // Enable validation
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
  }));
  
  // Set global prefix for API routes
  app.setGlobalPrefix('api');
  
  const port = process.env.PORT ?? 3001;
  await app.listen(port);
  console.log(`🚀 Backend API running on port ${port}`);
}
bootstrap();
