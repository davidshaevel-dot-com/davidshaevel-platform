# DavidShaevel.com Backend API

Production-ready Nest.js backend API with PostgreSQL database integration, health checks, and Prometheus metrics for the DavidShaevel.com platform engineering portfolio.

## 🚀 Technology Stack

- **Framework:** Nest.js 10+ (Node.js 20)
- **Language:** TypeScript 5
- **ORM:** TypeORM
- **Database:** PostgreSQL 15.12 (AWS RDS)
- **Validation:** class-validator, class-transformer
- **Runtime:** Node.js 20 (Alpine Linux in Docker)

## 📋 Features

- ✅ RESTful API with CRUD operations for projects
- ✅ Health check endpoint with database connection status (`/api/health`)
- ✅ Prometheus metrics endpoint (`/api/metrics`)
- ✅ TypeORM with PostgreSQL integration
- ✅ Environment-based configuration
- ✅ Request validation with DTOs
- ✅ CORS enabled for frontend
- ✅ Global API prefix (`/api`)
- ✅ Docker containerization (multi-stage build)
- ✅ Production-ready with non-root user
- ✅ Health checks configured

## 🏗️ Architecture

```
backend/
├── src/
│   ├── health/              # Health check module
│   │   ├── health.controller.ts
│   │   ├── health.service.ts
│   │   └── health.module.ts
│   ├── metrics/             # Metrics module
│   │   ├── metrics.controller.ts
│   │   ├── metrics.service.ts
│   │   └── metrics.module.ts
│   ├── projects/            # Projects CRUD module
│   │   ├── dto/
│   │   │   ├── create-project.dto.ts
│   │   │   └── update-project.dto.ts
│   │   ├── project.entity.ts
│   │   ├── projects.controller.ts
│   │   ├── projects.service.ts
│   │   └── projects.module.ts
│   ├── app.controller.ts
│   ├── app.service.ts
│   ├── app.module.ts       # Root module with TypeORM config
│   └── main.ts             # Application entry point
├── Dockerfile              # Multi-stage production build
├── .dockerignore
├── package.json
└── tsconfig.json
```

## 🔧 Getting Started

### Prerequisites

- Node.js 20+
- npm or yarn
- PostgreSQL 15+ (local or RDS)
- Docker (for containerization)

### Environment Variables

Create a `.env.local` file in the `backend/` directory:

```bash
# Server Configuration
NODE_ENV=development
PORT=3001

# Database Configuration
DB_HOST=localhost                                          # or RDS endpoint
DB_PORT=5432
DB_NAME=davidshaevel
DB_USERNAME=dbadmin
DB_PASSWORD=your-secure-password

# For production (ECS), these will be injected from AWS Secrets Manager
```

**Note:** Never commit `.env.local` or `.env` files to version control.

### Local Development

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env.local
   # Edit .env.local with your database credentials
   ```

3. **Run the application:**
   ```bash
   # Development mode with hot reload
   npm run start:dev

   # Production mode
   npm run build
   npm run start:prod
   ```

4. **Verify the application:**
   ```bash
   # Health check
   curl http://localhost:3001/api/health

   # Metrics
   curl http://localhost:3001/api/metrics

   # List projects
   curl http://localhost:3001/api/projects
   ```

### Database Migrations

TypeORM is configured with `synchronize: true` in development mode, which automatically syncs the schema. **This is disabled in production.**

For production, use migrations:

```bash
# Generate migration
npm run migration:generate -- -n MigrationName

# Run migrations
npm run migration:run

# Revert migrations
npm run migration:revert
```

## 🐳 Docker

### Build Image

```bash
docker build -t davidshaevel-backend:latest .
```

### Run Container

```bash
docker run -d \
  --name backend \
  -p 3001:3001 \
  -e NODE_ENV=production \
  -e DB_HOST=your-rds-endpoint.rds.amazonaws.com \
  -e DB_PORT=5432 \
  -e DB_NAME=davidshaevel \
  -e DB_USERNAME=dbadmin \
  -e DB_PASSWORD=your-password \
  davidshaevel-backend:latest
```

### Health Check

The Docker container includes a built-in health check that queries `/api/health` every 30 seconds:

```bash
docker ps  # Check HEALTH status
```

## 📡 API Endpoints

### Health Check

**GET** `/api/health`

Returns the health status of the application and database connection.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-29T12:00:00.000Z",
  "version": "1.0.0",
  "service": "backend",
  "uptime": 3600.5,
  "environment": "production",
  "database": {
    "status": "connected",
    "type": "postgresql"
  }
}
```

**Response (503 Service Unavailable)** if database is down:
```json
{
  "status": "unhealthy",
  "timestamp": "2025-10-29T12:00:00.000Z",
  "version": "1.0.0",
  "service": "backend",
  "uptime": 3600.5,
  "environment": "production",
  "database": {
    "status": "error",
    "type": "postgresql",
    "error": "Connection timeout"
  }
}
```

### Metrics

**GET** `/api/metrics`

Returns Prometheus-compatible metrics in text format.

**Response (200 OK):**
```text
# HELP backend_uptime_seconds Application uptime in seconds
# TYPE backend_uptime_seconds counter
backend_uptime_seconds 3600.5

# HELP backend_info Backend application information
# TYPE backend_info gauge
backend_info{version="1.0.0",environment="production"} 1

# HELP nodejs_memory_usage_bytes Node.js memory usage in bytes
# TYPE nodejs_memory_usage_bytes gauge
nodejs_memory_usage_bytes{type="rss"} 50331648
nodejs_memory_usage_bytes{type="heapTotal"} 20971520
nodejs_memory_usage_bytes{type="heapUsed"} 15728640
nodejs_memory_usage_bytes{type="external"} 1048576
```

### Projects CRUD

#### List Projects

**GET** `/api/projects`

Returns all active projects sorted by `sortOrder` and `createdAt`.

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "DavidShaevel.com Platform",
    "description": "Production-grade AWS infrastructure with Terraform, ECS Fargate, and CloudFront",
    "imageUrl": "https://example.com/image.png",
    "projectUrl": "https://davidshaevel.com",
    "githubUrl": "https://github.com/dshaevel/davidshaevel-platform",
    "technologies": ["AWS", "Terraform", "ECS", "CloudFront", "Next.js", "Nest.js"],
    "isActive": true,
    "sortOrder": 0,
    "createdAt": "2025-10-29T12:00:00.000Z",
    "updatedAt": "2025-10-29T12:00:00.000Z"
  }
]
```

#### Get Project

**GET** `/api/projects/:id`

Returns a single project by ID.

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "DavidShaevel.com Platform",
  "description": "Production-grade AWS infrastructure...",
  ...
}
```

**Response (404 Not Found):**
```json
{
  "statusCode": 404,
  "message": "Project with ID 550e8400-e29b-41d4-a716-446655440000 not found",
  "error": "Not Found"
}
```

#### Create Project

**POST** `/api/projects`

Creates a new project.

**Request Body:**
```json
{
  "title": "My New Project",
  "description": "A detailed description of the project",
  "imageUrl": "https://example.com/image.png",
  "projectUrl": "https://myproject.com",
  "githubUrl": "https://github.com/user/repo",
  "technologies": ["React", "Node.js", "PostgreSQL"],
  "isActive": true,
  "sortOrder": 0
}
```

**Response (201 Created):**
```json
{
  "id": "660f9500-f29b-41d4-a716-556766550000",
  "title": "My New Project",
  "description": "A detailed description of the project",
  ...
  "createdAt": "2025-10-29T12:00:00.000Z",
  "updatedAt": "2025-10-29T12:00:00.000Z"
}
```

#### Update Project

**PUT** `/api/projects/:id`

Updates an existing project.

**Request Body:**
```json
{
  "title": "Updated Title",
  "isActive": false
}
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Updated Title",
  "isActive": false,
  ...
  "updatedAt": "2025-10-29T13:00:00.000Z"
}
```

#### Delete Project

**DELETE** `/api/projects/:id`

Deletes a project by ID.

**Response (204 No Content)**

## 🧪 Testing

```bash
# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Test coverage
npm run test:cov
```

## 📦 Database Schema

### Projects Table

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `title` | VARCHAR(200) | Project title |
| `description` | TEXT | Detailed description |
| `imageUrl` | VARCHAR(500) | Optional image URL |
| `projectUrl` | VARCHAR(500) | Optional live project URL |
| `githubUrl` | VARCHAR(500) | Optional GitHub repository URL |
| `technologies` | TEXT[] | Array of technology tags |
| `isActive` | BOOLEAN | Whether project is active (default: true) |
| `sortOrder` | INTEGER | Display order (default: 0) |
| `createdAt` | TIMESTAMP | Creation timestamp |
| `updatedAt` | TIMESTAMP | Last update timestamp |

## 🔒 Security

- ✅ Non-root user in Docker container (`nestjs:nodejs`)
- ✅ Production dependencies only in final image
- ✅ Request validation with DTOs
- ✅ CORS enabled (configurable)
- ✅ Environment variables for secrets
- ✅ AWS Secrets Manager integration in ECS

## 🚀 Deployment

### AWS ECS Fargate

The backend is deployed to AWS ECS Fargate with:

- **Task Definition:** davidshaevel-dev-task
- **Service:** davidshaevel-dev-service
- **Port:** 3001 (internal)
- **Health Check:** `/api/health`
- **Database:** RDS PostgreSQL (private subnet)
- **Secrets:** AWS Secrets Manager
- **Load Balancer:** Application Load Balancer

**Environment Variables (ECS):**
- `NODE_ENV=production`
- `PORT=3001`
- `DB_HOST` (from terraform output)
- `DB_PORT=5432`
- `DB_NAME=davidshaevel`
- `DB_USERNAME` (from Secrets Manager)
- `DB_PASSWORD` (from Secrets Manager)

### Build and Push to ECR

```bash
# Get RDS connection details
cd terraform/environments/dev
source ../../../.envrc
terraform output database_endpoint

# Build image
cd ../../../backend
docker build -t davidshaevel-backend:latest .

# Tag and push to ECR (after TT-23)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag davidshaevel-backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/davidshaevel-backend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/davidshaevel-backend:latest
```

## 📊 Monitoring

The backend exposes metrics for Prometheus scraping at `/api/metrics`. These include:

- Application uptime
- Memory usage (RSS, heap total, heap used, external)
- Environment information
- Version information

Future enhancements:
- HTTP request metrics (request count, duration, status codes)
- Database query metrics
- Custom business metrics

## 🐛 Troubleshooting

### Database Connection Issues

**Error:** `ECONNREFUSED` or `Connection timeout`

**Solutions:**
1. Verify database credentials in `.env.local`
2. Check security group rules (port 5432 open)
3. Verify RDS endpoint is accessible
4. Check VPC/subnet configuration

### Port Already in Use

**Error:** `EADDRINUSE: address already in use :::3001`

**Solution:**
```bash
# Find process using port 3001
lsof -i :3001

# Kill the process
kill -9 <PID>
```

### Docker Build Issues

**Error:** `npm ERR! code ENOENT`

**Solution:** Ensure `.dockerignore` excludes `node_modules` and `dist` directories.

## 📚 Additional Resources

- [Nest.js Documentation](https://docs.nestjs.com/)
- [TypeORM Documentation](https://typeorm.io/)
- [AWS ECS Fargate](https://aws.amazon.com/fargate/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 👨‍💻 Author

**David Shaevel**
- Website: https://davidshaevel.com
- GitHub: https://github.com/dshaevel
- LinkedIn: https://linkedin.com/in/dshaevel

## 📄 License

This project is private and proprietary.

---

**Last Updated:** October 29, 2025
**Version:** 1.0.0
**Status:** ✅ Production Ready
