# ==============================================================================
# Networking Module - Complete VPC Infrastructure (Steps 4-5)
# ==============================================================================
# This module creates the complete networking infrastructure:
#
# Step 4 (VPC Foundation):
# - VPC with DNS support (10.0.0.0/16)
# - Internet Gateway for public internet access
#
# Step 5 (Subnets and Routing):
# - Public subnets (2 AZs) with auto-assign public IPs
# - Private application subnets (2 AZs)
# - Private database subnets (2 AZs)
# - NAT Gateways for private subnet internet access (HA configuration)
# - Route tables and associations
# - VPC Flow Logs to CloudWatch for network monitoring
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-vpc"
  })
}

# ------------------------------------------------------------------------------
# Internet Gateway
# ------------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-igw"
  })
}

# ------------------------------------------------------------------------------
# Public Subnets (Step 5)
# ------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-public-subnet-${count.index + 1}"
    Tier = "public"
    AZ   = var.availability_zones[count.index]
  })
}

# ------------------------------------------------------------------------------
# Private Application Subnets (Step 5)
# ------------------------------------------------------------------------------

resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-private-app-subnet-${count.index + 1}"
    Tier = "private-app"
    AZ   = var.availability_zones[count.index]
  })
}

# ------------------------------------------------------------------------------
# Private Database Subnets (Step 5)
# ------------------------------------------------------------------------------

resource "aws_subnet" "private_db" {
  count = length(var.private_db_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-private-db-subnet-${count.index + 1}"
    Tier = "private-db"
    AZ   = var.availability_zones[count.index]
  })
}

# ------------------------------------------------------------------------------
# Elastic IPs for NAT Gateways (Step 5)
# ------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# NAT Gateways (Step 5)
# ------------------------------------------------------------------------------

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-nat-gw-${count.index + 1}"
    AZ   = var.availability_zones[count.index]
  })

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# Public Route Table (Step 5)
# ------------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# Private Route Tables (Step 5)
# ------------------------------------------------------------------------------
# One route table per AZ for high availability
# Each routes to its local NAT Gateway

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0

  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-private-rt-${count.index + 1}"
    Tier = "private"
    AZ   = var.availability_zones[count.index]
  })
}

resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
}

# Associate private app subnets with their AZ-specific route table
resource "aws_route_table_association" "private_app" {
  count = var.enable_nat_gateway ? length(var.private_app_subnet_cidrs) : 0

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Associate private db subnets with their AZ-specific route table
resource "aws_route_table_association" "private_db" {
  count = var.enable_nat_gateway ? length(var.private_db_subnet_cidrs) : 0

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ------------------------------------------------------------------------------
# VPC Flow Logs (Step 5)
# ------------------------------------------------------------------------------

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.environment}-${var.project_name}-flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-vpc-flow-logs"
  })
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.environment}-${var.project_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-vpc-flow-logs-role"
  })
}

# IAM policy for VPC Flow Logs to write to CloudWatch
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.environment}-${var.project_name}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = format(<<-EOT
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ],
          "Resource": "%s:*"
        }
      ]
    }
    EOT
  , aws_cloudwatch_log_group.flow_logs[0].arn)
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-vpc-flow-logs"
  })
}

# ==============================================================================
# Security Groups (Step 6)
# ==============================================================================
# Security groups implement a three-tier security architecture with least
# privilege access control:
# - ALB tier: Public internet access (HTTP/HTTPS)
# - Application tier: Access from ALB only
# - Database tier: Access from application tier only
# ==============================================================================

# ------------------------------------------------------------------------------
# ALB Security Group
# ------------------------------------------------------------------------------
# Load balancer security group - accepts HTTPS/HTTP from internet

resource "aws_security_group" "alb" {
  name_prefix = "${var.environment}-${var.project_name}-alb-sg-"
  description = "Security group for Application Load Balancer - allows HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  # NOTE: All rules are managed by separate aws_vpc_security_group_*_rule resources
  # We use lifecycle ignore_changes to prevent drift when using separate rule resources

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-alb-sg"
    Tier = "public"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [egress, ingress]
  }
}

# Allow inbound HTTP from internet (redirect to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "Allow HTTP from internet (redirect to HTTPS)"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-alb-http-ingress"
  })
}

# Allow inbound HTTPS from internet
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  description = "Allow HTTPS from internet"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-alb-https-ingress"
  })
}

# Allow outbound to frontend containers
resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id = aws_security_group.alb.id

  description                  = "Allow traffic to frontend containers"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_frontend.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-alb-to-frontend-egress"
  })
}

# Allow outbound to backend containers
resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id = aws_security_group.alb.id

  description                  = "Allow traffic to backend containers"
  from_port                    = 3001
  to_port                      = 3001
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_backend.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-alb-to-backend-egress"
  })
}

# ------------------------------------------------------------------------------
# Application Tier - Frontend Security Group
# ------------------------------------------------------------------------------
# Frontend container security group - accepts traffic from ALB only

resource "aws_security_group" "app_frontend" {
  name_prefix = "${var.environment}-${var.project_name}-app-frontend-sg-"
  description = "Security group for frontend containers - allows traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  # NOTE: All rules are managed by separate aws_vpc_security_group_*_rule resources
  # We use lifecycle ignore_changes to prevent drift when using separate rule resources

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-app-frontend-sg"
    Tier = "private-app"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [egress, ingress]
  }
}

# Allow inbound from ALB on port 3000
resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id = aws_security_group.app_frontend.id

  description                  = "Allow traffic from ALB"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-frontend-from-alb-ingress"
  })
}

# Allow outbound to backend containers
resource "aws_vpc_security_group_egress_rule" "frontend_to_backend" {
  security_group_id = aws_security_group.app_frontend.id

  description                  = "Allow traffic to backend containers"
  from_port                    = 3001
  to_port                      = 3001
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_backend.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-frontend-to-backend-egress"
  })
}

# Allow outbound HTTPS to internet (for external APIs, CDNs)
resource "aws_vpc_security_group_egress_rule" "frontend_to_internet" {
  security_group_id = aws_security_group.app_frontend.id

  description = "Allow HTTPS to internet for external APIs and CDNs"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-frontend-to-internet-egress"
  })
}

# ------------------------------------------------------------------------------
# Application Tier - Backend Security Group
# ------------------------------------------------------------------------------
# Backend container security group - accepts traffic from ALB and frontend

resource "aws_security_group" "app_backend" {
  name_prefix = "${var.environment}-${var.project_name}-app-backend-sg-"
  description = "Security group for backend containers - allows traffic from ALB and frontend"
  vpc_id      = aws_vpc.main.id

  # NOTE: All rules are managed by separate aws_vpc_security_group_*_rule resources
  # We use lifecycle ignore_changes to prevent drift when using separate rule resources

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-app-backend-sg"
    Tier = "private-app"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [egress, ingress]
  }
}

# Allow inbound from ALB on port 3001
resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id = aws_security_group.app_backend.id

  description                  = "Allow traffic from ALB"
  from_port                    = 3001
  to_port                      = 3001
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-backend-from-alb-ingress"
  })
}

# Allow inbound from frontend on port 3001
resource "aws_vpc_security_group_ingress_rule" "backend_from_frontend" {
  security_group_id = aws_security_group.app_backend.id

  description                  = "Allow traffic from frontend containers"
  from_port                    = 3001
  to_port                      = 3001
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_frontend.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-backend-from-frontend-ingress"
  })
}

# Allow outbound to database on PostgreSQL port
resource "aws_vpc_security_group_egress_rule" "backend_to_database" {
  security_group_id = aws_security_group.app_backend.id

  description                  = "Allow traffic to PostgreSQL database"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.database.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-backend-to-database-egress"
  })
}

# Allow outbound HTTPS to internet (for external APIs)
resource "aws_vpc_security_group_egress_rule" "backend_to_internet" {
  security_group_id = aws_security_group.app_backend.id

  description = "Allow HTTPS to internet for external APIs"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-backend-to-internet-egress"
  })
}

# ------------------------------------------------------------------------------
# Database Tier Security Group
# ------------------------------------------------------------------------------
# Database security group - accepts traffic from backend only

resource "aws_security_group" "database" {
  name_prefix = "${var.environment}-${var.project_name}-database-sg-"
  description = "Security group for RDS PostgreSQL database - allows traffic from backend only"
  vpc_id      = aws_vpc.main.id

  # NOTE: All rules are managed by separate aws_vpc_security_group_*_rule resources
  # We use lifecycle ignore_changes to prevent drift when using separate rule resources
  # Database has no egress rules (fully isolated)

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-database-sg"
    Tier = "private-db"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [egress, ingress]
  }
}

# Allow inbound from backend on PostgreSQL port
resource "aws_vpc_security_group_ingress_rule" "database_from_backend" {
  security_group_id = aws_security_group.database.id

  description                  = "Allow PostgreSQL traffic from backend containers"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_backend.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-database-from-backend-ingress"
  })
}

# No egress rules for database - databases should not initiate outbound connections
# AWS default implicit deny will apply

