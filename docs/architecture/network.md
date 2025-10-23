# Network Architecture

**Project:** DavidShaevel.com Platform  
**Date:** October 23, 2025  
**Author:** David Shaevel  
**Version:** 1.0

## Overview

This document describes the network architecture for the DavidShaevel.com platform, including VPC design, subnet allocation, routing, and network security controls.

## VPC Design

### VPC Configuration

**VPC CIDR:** `10.0.0.0/16`  
**Region:** `us-east-1` (Northern Virginia)  
**Availability Zones:** 2 (us-east-1a, us-east-1b)  
**DNS Hostnames:** Enabled  
**DNS Resolution:** Enabled

### Design Principles

1. **Multi-AZ Deployment:** Resources distributed across 2 AZs for high availability
2. **Network Isolation:** Public and private subnet segregation
3. **Least Privilege:** Security groups implement minimal required access
4. **Defense in Depth:** Multiple layers of network security (NACLs + Security Groups)
5. **Scalability:** CIDR blocks sized for future growth

## Subnet Architecture

### Public Subnets (Internet-facing)

**Purpose:** ALB, NAT Gateways, Bastion hosts (if needed)

| Subnet Name | CIDR | AZ | Resources |
|-------------|------|-----|-----------|
| public-subnet-1 | 10.0.1.0/24 | us-east-1a | ALB, NAT Gateway |
| public-subnet-2 | 10.0.2.0/24 | us-east-1b | ALB, NAT Gateway |

**Characteristics:**
- Direct route to Internet Gateway
- Elastic IPs for NAT Gateways
- Auto-assign public IPv4 addresses: Enabled

### Private Subnets - Application Tier

**Purpose:** ECS tasks (frontend and backend containers)

| Subnet Name | CIDR | AZ | Resources |
|-------------|------|-----|-----------|
| private-app-subnet-1 | 10.0.11.0/24 | us-east-1a | ECS Tasks |
| private-app-subnet-2 | 10.0.12.0/24 | us-east-1b | ECS Tasks |

**Characteristics:**
- Route to internet via NAT Gateway in same AZ
- No direct internet access
- Can initiate outbound connections (for package downloads, API calls)

### Private Subnets - Database Tier

**Purpose:** RDS PostgreSQL instances

| Subnet Name | CIDR | AZ | Resources |
|-------------|------|-----|-----------|
| private-db-subnet-1 | 10.0.21.0/24 | us-east-1a | RDS Primary |
| private-db-subnet-2 | 10.0.22.0/24 | us-east-1b | RDS Standby |

**Characteristics:**
- No route to internet (fully isolated)
- Only accessible from application tier
- RDS subnet group spans both subnets

## Network Components

### Internet Gateway

**Name:** `davidshaevel-igw`  
**Purpose:** Provide internet access to resources in public subnets

**Attached to:** VPC  
**Route Target:** 0.0.0.0/0 from public subnets

### NAT Gateways

**High Availability:** One NAT Gateway per AZ

| NAT Gateway | Subnet | AZ | Elastic IP |
|-------------|--------|-----|------------|
| nat-gw-1 | public-subnet-1 | us-east-1a | Auto-allocated |
| nat-gw-2 | public-subnet-2 | us-east-1b | Auto-allocated |

**Purpose:** Allow private subnet resources to access internet for:
- Package downloads (npm, apt)
- External API calls
- Software updates

**Cost Optimization Note:** For development environment, could use single NAT Gateway to reduce costs (~$32/month savings). Production should use 2 for HA.

## Route Tables

### Public Route Table

**Name:** `public-rt`  
**Associated Subnets:** public-subnet-1, public-subnet-2

| Destination | Target | Purpose |
|-------------|--------|---------|
| 10.0.0.0/16 | local | Internal VPC routing |
| 0.0.0.0/0 | igw-xxxx | Internet access |

### Private Route Table - AZ 1

**Name:** `private-app-rt-1`  
**Associated Subnets:** private-app-subnet-1

| Destination | Target | Purpose |
|-------------|--------|---------|
| 10.0.0.0/16 | local | Internal VPC routing |
| 0.0.0.0/0 | nat-gw-1 | Internet access via NAT |

### Private Route Table - AZ 2

**Name:** `private-app-rt-2`  
**Associated Subnets:** private-app-subnet-2

| Destination | Target | Purpose |
|-------------|--------|---------|
| 10.0.0.0/16 | local | Internal VPC routing |
| 0.0.0.0/0 | nat-gw-2 | Internet access via NAT |

### Database Route Table

**Name:** `private-db-rt`  
**Associated Subnets:** private-db-subnet-1, private-db-subnet-2

| Destination | Target | Purpose |
|-------------|--------|---------|
| 10.0.0.0/16 | local | Internal VPC routing only |

**Note:** No internet route - database tier is fully isolated

## Security Groups

### ALB Security Group

**Name:** `alb-sg`  
**Purpose:** Control traffic to Application Load Balancer

**Inbound Rules:**

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 80 | TCP | 0.0.0.0/0 | HTTP (redirect to HTTPS) |
| 443 | TCP | 0.0.0.0/0 | HTTPS traffic |

**Outbound Rules:**

| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| 3000 | TCP | frontend-sg | Frontend container |
| 3001 | TCP | backend-sg | Backend container |

### Frontend Security Group

**Name:** `frontend-sg`  
**Purpose:** Control traffic to Next.js containers

**Inbound Rules:**

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 3000 | TCP | alb-sg | Traffic from ALB |

**Outbound Rules:**

| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| 3001 | TCP | backend-sg | Backend API calls |
| 443 | TCP | 0.0.0.0/0 | External API calls (HTTPS) |

### Backend Security Group

**Name:** `backend-sg`  
**Purpose:** Control traffic to Nest.js containers

**Inbound Rules:**

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 3001 | TCP | alb-sg | Traffic from ALB |
| 3001 | TCP | frontend-sg | Traffic from frontend |

**Outbound Rules:**

| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| 5432 | TCP | db-sg | PostgreSQL database |
| 443 | TCP | 0.0.0.0/0 | External API calls (HTTPS) |

### Database Security Group

**Name:** `db-sg`  
**Purpose:** Control traffic to RDS PostgreSQL

**Inbound Rules:**

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 5432 | TCP | backend-sg | Backend database access |

**Outbound Rules:**

| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| All | All | Deny | No outbound access needed |

### ECS Instance Security Group

**Name:** `ecs-instance-sg`  
**Purpose:** Control traffic to ECS EC2 instances

**Inbound Rules:**

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 32768-65535 | TCP | alb-sg | Dynamic port range for containers |

**Outbound Rules:**

| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| All | All | 0.0.0.0/0 | Container image pulls, updates |

## Network ACLs

### Public Subnet NACL

**Default:** Allow all inbound/outbound (AWS default)

**Custom Rules (Optional Enhancement):**

**Inbound:**
- Allow 80, 443 from 0.0.0.0/0
- Allow 1024-65535 from 0.0.0.0/0 (ephemeral ports)
- Deny all other traffic

**Outbound:**
- Allow all to 0.0.0.0/0

### Private Subnet NACL

**Default:** Allow all inbound/outbound (AWS default)

**Note:** Security groups provide sufficient protection for this architecture. NACLs left at default to avoid complexity, but can be tightened in production.

## VPC Flow Logs

**Purpose:** Network traffic monitoring and security analysis

**Configuration:**
- **Destination:** CloudWatch Logs
- **Log Group:** `/aws/vpc/davidshaevel-platform`
- **Traffic Type:** ALL (Accept and Reject)
- **Format:** Default format
- **Retention:** 7 days (development), 30 days (production)

**Use Cases:**
- Troubleshooting connectivity issues
- Security analysis and threat detection
- Compliance auditing
- Network performance analysis

## VPC Endpoints (Optional - Cost Optimization)

**Future Enhancement:** VPC endpoints can reduce NAT Gateway data transfer costs

**Candidates for VPC Endpoints:**
- S3 Gateway Endpoint (free)
- ECR API Endpoint (container image pulls)
- ECR DKR Endpoint (Docker registry)
- CloudWatch Logs Endpoint
- Secrets Manager Endpoint

**Estimated Savings:** ~$5-10/month for development environment

## Network Monitoring

### CloudWatch Metrics

**Monitored Metrics:**
- NAT Gateway bytes in/out
- NAT Gateway packet count
- VPC Flow Log delivery status

### Alarms

1. **High NAT Gateway Usage**
   - Metric: BytesOutToSource > 10GB/hour
   - Action: SNS notification

2. **Flow Log Delivery Failures**
   - Metric: DeliveryFailures > 0
   - Action: SNS notification

## Security Best Practices

1. **Principle of Least Privilege:** Security groups only allow required ports
2. **Defense in Depth:** Multiple security layers (NACLs + SGs)
3. **Network Segmentation:** Clear separation of public, app, and data tiers
4. **High Availability:** Multi-AZ deployment for all critical components
5. **Monitoring:** VPC Flow Logs enabled for all network traffic
6. **Encryption:** All traffic within VPC uses encryption where possible

## Resource Naming Conventions

**Format:** `{environment}-{resource-type}-{purpose}-{az}`

**Examples:**
- `dev-subnet-public-1a`
- `prod-sg-backend`
- `dev-nat-gw-1a`
- `prod-rtb-private-app`

**Environment Prefixes:**
- `dev` - Development environment
- `prod` - Production environment

## Network Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────▼────────-┐
                    │ Internet Gateway │
                    └────────┬────────-┘
                             │
        ┌────────────────────┴────────────────────┐
        │            VPC: 10.0.0.0/16             │
        │                                         │
        │  ┌─────────────────────────────────┐    │
        │  │      Public Subnets             │    │
        │  │  ┌──────────┐    ┌──────────┐   │    │
        │  │  │   ALB    │    │   ALB    │   │    │
        │  │  │ (1.0/24) │    │ (2.0/24) │   │    │
        │  │  └────┬─────┘    └─────┬────┘   │    │
        │  │       │  NAT-GW-1      │  NAT-GW-2   │
        │  └───────┼────────────────┼───────-┘    │
        │          │                │             │
        │  ┌───────▼────────────────▼────────┐    │
        │  │   Private App Subnets           │    │
        │  │  ┌──────────┐    ┌──────────┐   │    │
        │  │  │   ECS    │    │   ECS    │   │    │
        │  │  │ Frontend │    │ Frontend │   │    │
        │  │  │ Backend  │    │ Backend  │   │    │
        │  │  │(11.0/24) │    │(12.0/24) │   │    │
        │  │  └────┬─────┘    └─────┬────┘   │    │
        │  └───────┼────────────────┼───────-┘    │
        │          │                │             │
        │  ┌───────▼────────────────▼───────-┐    │
        │  │   Private DB Subnets            │    │
        │  │  ┌──────────┐    ┌──────────┐   │    │
        │  │  │   RDS    │◄───┤   RDS    │   │    │
        │  │  │ Primary  │    │ Standby  │   │    │
        │  │  │(21.0/24) │    │(22.0/24) │   │    │
        │  │  └──────────┘    └──────────┘   │    │
        │  └─────────────────────────────────┘    │
        │                                         │
        │    us-east-1a        us-east-1b         │
        └────────────────────────────────────────-┘
```

## Cost Estimation

**Monthly Network Costs (Development):**

| Resource | Quantity | Cost |
|----------|----------|------|
| NAT Gateway | 2 | ~$64 |
| NAT Gateway Data Transfer | ~100GB | ~$4.50 |
| VPC (free) | 1 | $0 |
| Elastic IPs | 2 (attached) | $0 |

**Total Network Cost:** ~$68.50/month

**Production Cost:** Similar, with higher data transfer costs

**Cost Optimization Options:**
1. Use single NAT Gateway in dev: Save ~$32/month
2. Implement VPC endpoints: Save ~$5-10/month on data transfer
3. Use NAT instances instead: Save ~$40/month (less reliable)

---

**Last Updated:** October 23, 2025  
**Next Review:** After initial deployment

