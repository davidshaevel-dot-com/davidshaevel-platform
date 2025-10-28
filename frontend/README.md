# DavidShaevel.com - Frontend Application

Modern, production-ready Next.js frontend application demonstrating platform engineering expertise.

## Overview

This is the frontend component of the DavidShaevel.com platform, built with Next.js 16, React 19, TypeScript, and Tailwind CSS. It showcases a professional portfolio with emphasis on platform engineering, AWS cloud architecture, and DevOps best practices.

## Technology Stack

- **Framework:** Next.js 16 with App Router
- **Language:** TypeScript 5
- **Styling:** Tailwind CSS 4
- **Container:** Docker with multi-stage builds
- **Deployment:** AWS ECS Fargate
- **Monitoring:** Prometheus metrics endpoint

## Features

- ✅ **Health Check Endpoint** (`/api/health`) - For ALB target health checks
- ✅ **Metrics Endpoint** (`/api/metrics`) - Prometheus-compatible metrics
- ✅ **Responsive Design** - Mobile-first, works on all devices
- ✅ **Dark Mode** - Automatic dark mode support
- ✅ **Static Pages** - Home, About, Projects, Contact
- ✅ **Production-Optimized** - Multi-stage Docker builds
- ✅ **Type-Safe** - Full TypeScript coverage
- ✅ **Modern UI** - Tailwind CSS with custom components

## Getting Started

### Prerequisites

- Node.js 20 or later
- npm 11 or later

### Local Development

1. **Install dependencies:**
```bash
npm install
```

2. **Run the development server:**
```bash
npm run dev
```

3. **Open in browser:**
```
http://localhost:3000
```

The page will auto-reload when you make changes.

### Available Scripts

- `npm run dev` - Start development server with Turbopack
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint

## Project Structure

```
frontend/
├── app/                    # Next.js App Router pages and layouts
│   ├── about/             # About page
│   ├── contact/           # Contact page
│   ├── projects/          # Projects showcase page
│   ├── api/               # API routes
│   │   ├── health/        # Health check endpoint
│   │   └── metrics/       # Prometheus metrics
│   ├── layout.tsx         # Root layout with navigation
│   ├── page.tsx           # Home page
│   └── globals.css        # Global styles
├── components/            # Reusable React components
│   ├── Navigation.tsx     # Site navigation
│   └── Footer.tsx         # Site footer
├── lib/                   # Utility functions
├── public/                # Static assets
├── Dockerfile             # Multi-stage production build
├── .dockerignore          # Docker build exclusions
├── package.json           # Dependencies and scripts
└── tsconfig.json          # TypeScript configuration
```

## API Endpoints

### Health Check

**Endpoint:** `GET /api/health`

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-28T12:00:00.000Z",
  "version": "1.0.0",
  "service": "frontend",
  "uptime": 12345.67,
  "environment": "production"
}
```

**Usage:** AWS ALB target group health checks

### Metrics

**Endpoint:** `GET /api/metrics`

**Response:** Prometheus-compatible metrics in text format

**Metrics Exposed:**
- `frontend_uptime_seconds` - Application uptime
- `frontend_info` - Application version and environment
- `nodejs_memory_usage_bytes` - Memory usage by type

**Usage:** Prometheus scraping for observability

## Docker Deployment

### Building the Image

```bash
docker build -t davidshaevel-frontend:latest .
```

### Running Locally

```bash
docker run -p 3000:3000 davidshaevel-frontend:latest
```

### Environment Variables

Create a `.env.local` file for local development (not committed):

```env
NODE_ENV=development
PORT=3000
```

See `.env.example` for all available configuration options.

## Production Deployment

This application is designed to be deployed on AWS ECS Fargate with the following architecture:

1. **Container:** Docker image pushed to Amazon ECR
2. **Compute:** ECS Fargate tasks (2 for high availability)
3. **Load Balancer:** Application Load Balancer (ALB)
4. **CDN:** CloudFront distribution
5. **DNS:** Custom domain via Route53/Cloudflare
6. **Monitoring:** CloudWatch + Prometheus metrics

### ECS Task Definition Requirements

- **Port:** 3000
- **Health Check:** `/api/health`
- **Memory:** 512 MB (minimum)
- **CPU:** 256 units (0.25 vCPU minimum)

### Health Check Configuration

ALB Target Group should use:
- **Path:** `/api/health`
- **Interval:** 30 seconds
- **Timeout:** 5 seconds
- **Healthy Threshold:** 2
- **Unhealthy Threshold:** 3

## Pages

### Home (`/`)
Landing page with hero section, core competencies showcase, and call-to-action.

### About (`/about`)
Professional bio, technical expertise, approach to platform engineering, and location.

### Projects (`/projects`)
Showcase of the platform engineering portfolio project with architecture overview, tech stack, and key features.

### Contact (`/contact`)
Contact form (client-side), contact information, location, and social links.

## Development Guidelines

### Component Structure
- Use functional components with TypeScript
- Extract reusable components to `components/`
- Use Tailwind CSS for styling
- Follow Next.js App Router patterns

### Styling
- Tailwind CSS utility classes
- Dark mode support with `dark:` prefix
- Responsive design with `sm:`, `md:`, `lg:` breakpoints
- Custom colors using zinc palette

### Type Safety
- All files use `.tsx` extension
- Explicit types for props and state
- Strict TypeScript configuration

## Performance Optimizations

- Static page generation for all pages
- Optimized images with Next.js Image component
- Multi-stage Docker builds for small image size
- Production build minification
- Automatic code splitting

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile browsers (iOS Safari, Chrome Mobile)
- Automatic fallbacks for older browsers

## Contributing

This is a personal portfolio project, but feedback and suggestions are welcome.

## License

© 2025 David Shaevel. All rights reserved.

## Related Documentation

- [Project Root README](../README.md) - Overall project documentation
- [Terraform Documentation](../terraform/README.md) - Infrastructure as code
- [Backend Documentation](../backend/README.md) - API documentation (TT-19)

## Support

For questions or issues:
- **GitHub:** https://github.com/davidshaevel-dot-com/davidshaevel-platform
- **LinkedIn:** https://www.linkedin.com/in/dshaevel
- **Location:** Austin, Texas

---

**Built with ❤️ using Next.js, TypeScript, and Tailwind CSS**
