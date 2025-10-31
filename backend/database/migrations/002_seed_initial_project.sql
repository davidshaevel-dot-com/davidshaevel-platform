-- Migration: 002_seed_initial_project.sql
-- Description: Insert initial project data (DavidShaevel.com Platform)
-- Created: 2025-10-31
-- Author: David Shaevel

BEGIN;

-- Insert initial project showcasing this platform
-- Uses WHERE NOT EXISTS to ensure idempotency based on title
INSERT INTO projects (
    title,
    description,
    "imageUrl",
    "projectUrl",
    "githubUrl",
    technologies,
    "isActive",
    "sortOrder"
)
SELECT
    'DavidShaevel.com Platform Engineering Portfolio',
    'Production-grade full-stack web platform demonstrating DevOps and platform engineering expertise. Built with modern cloud-native technologies and deployed on AWS with comprehensive infrastructure automation.

Key Features:
• Infrastructure as Code (IaC) with Terraform modules
• Cloud-native architecture on AWS (ECS Fargate, RDS, CloudFront, ALB)
• Container orchestration with Docker and ECS
• CI/CD automation and deployment pipelines
• Comprehensive monitoring and observability
• Production-ready security best practices
• Multi-environment deployment strategy (dev/prod)

This project serves as both a personal website and a demonstration of production-ready DevOps practices suitable for enterprise-scale applications.',
    NULL,
    'https://davidshaevel.com',
    'https://github.com/davidshaevel-dot-com/davidshaevel-platform',
    ARRAY[
        'AWS',
        'Terraform',
        'Next.js 16',
        'Nest.js',
        'PostgreSQL',
        'Docker',
        'ECS Fargate',
        'TypeScript',
        'CloudFront',
        'RDS',
        'Application Load Balancer',
        'CloudWatch',
        'GitHub Actions'
    ],
    true,
    1
WHERE NOT EXISTS (
    SELECT 1 FROM projects WHERE title = 'DavidShaevel.com Platform Engineering Portfolio'
);

COMMIT;

-- Verify insertion
SELECT
    id,
    title,
    "projectUrl",
    "githubUrl",
    array_length(technologies, 1) as tech_count,
    "isActive",
    "sortOrder",
    "createdAt"
FROM projects
ORDER BY "sortOrder";
