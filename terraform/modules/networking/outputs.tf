# ==============================================================================
# Networking Module Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

# ------------------------------------------------------------------------------
# Internet Gateway Outputs
# ------------------------------------------------------------------------------

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "internet_gateway_arn" {
  description = "ARN of the Internet Gateway"
  value       = aws_internet_gateway.main.arn
}

# ------------------------------------------------------------------------------
# Subnet Outputs (for Step 5 implementation)
# ------------------------------------------------------------------------------
# These outputs will be populated when subnets are implemented in Step 5

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = []
}

output "private_app_subnet_ids" {
  description = "List of private application subnet IDs"
  value       = []
}

output "private_db_subnet_ids" {
  description = "List of private database subnet IDs"
  value       = []
}

# ------------------------------------------------------------------------------
# NAT Gateway Outputs (for Step 5 implementation)
# ------------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = []
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IP addresses"
  value       = []
}

# ------------------------------------------------------------------------------
# Route Table Outputs (for Step 5 implementation)
# ------------------------------------------------------------------------------

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = null
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = []
}

