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
# Subnet Outputs (Step 5)
# ------------------------------------------------------------------------------

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_app_subnet_ids" {
  description = "List of private application subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_app_subnet_cidrs" {
  description = "List of private application subnet CIDR blocks"
  value       = aws_subnet.private_app[*].cidr_block
}

output "private_db_subnet_ids" {
  description = "List of private database subnet IDs"
  value       = aws_subnet.private_db[*].id
}

output "private_db_subnet_cidrs" {
  description = "List of private database subnet CIDR blocks"
  value       = aws_subnet.private_db[*].cidr_block
}

# ------------------------------------------------------------------------------
# NAT Gateway Outputs (Step 5)
# ------------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IP addresses"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# ------------------------------------------------------------------------------
# Route Table Outputs (Step 5)
# ------------------------------------------------------------------------------

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = var.enable_nat_gateway ? aws_route_table.private[*].id : []
}

# ------------------------------------------------------------------------------
# VPC Flow Logs Outputs (Step 5)
# ------------------------------------------------------------------------------

output "flow_logs_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "flow_logs_log_group_arn" {
  description = "CloudWatch Log Group ARN for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].arn : null
}

# ------------------------------------------------------------------------------
# Security Group Outputs (Step 6)
# ------------------------------------------------------------------------------

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "app_frontend_security_group_id" {
  description = "ID of the frontend application security group"
  value       = aws_security_group.app_frontend.id
}

output "app_frontend_security_group_arn" {
  description = "ARN of the frontend application security group"
  value       = aws_security_group.app_frontend.arn
}

output "app_backend_security_group_id" {
  description = "ID of the backend application security group"
  value       = aws_security_group.app_backend.id
}

output "app_backend_security_group_arn" {
  description = "ARN of the backend application security group"
  value       = aws_security_group.app_backend.arn
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "database_security_group_arn" {
  description = "ARN of the database security group"
  value       = aws_security_group.database.arn
}

output "prometheus_security_group_id" {
  description = "ID of the Prometheus security group"
  value       = aws_security_group.prometheus.id
}

output "prometheus_security_group_arn" {
  description = "ARN of the Prometheus security group"
  value       = aws_security_group.prometheus.arn
}

