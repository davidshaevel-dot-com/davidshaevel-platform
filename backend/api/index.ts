import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ExpressAdapter } from '@nestjs/platform-express';
import serverlessExpress from '@vendia/serverless-express';
import express from 'express';
import type { Handler, APIGatewayProxyEvent, Context } from 'aws-lambda';
import { AppModule } from '../src/app.module.js';

let cachedServer: Handler;

async function bootstrap(): Promise<Handler> {
  if (cachedServer) {
    return cachedServer;
  }

  const expressApp = express();
  const adapter = new ExpressAdapter(expressApp);

  const app = await NestFactory.create(AppModule, adapter);

  // Enable CORS for frontend
  app.enableCors({
    origin: process.env.FRONTEND_URL || 'https://davidshaevel.com',
    credentials: true,
  });

  // Enable validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );

  // Set global prefix for API routes
  app.setGlobalPrefix('api');

  await app.init();

  cachedServer = serverlessExpress({ app: expressApp });
  return cachedServer;
}

export default async function handler(
  event: APIGatewayProxyEvent,
  context: Context,
): Promise<unknown> {
  const server = await bootstrap();
  return server(event, context, () => {});
}
