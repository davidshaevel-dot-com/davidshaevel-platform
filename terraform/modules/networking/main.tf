# ==============================================================================
# Networking Module - VPC and Internet Gateway (Step 4)
# ==============================================================================
# This module creates the foundational networking infrastructure:
# - VPC with DNS support
# - Internet Gateway for public internet access
#
# Future enhancements (Step 5):
# - Public, private app, and private database subnets
# - NAT Gateways for private subnet internet access
# - Route tables and associations
# - VPC Flow Logs
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

