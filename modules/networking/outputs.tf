# =============================================================================
# NETWORKING MODULE OUTPUTS
# =============================================================================
# Outputs expose important networking resource IDs that are required by
# other modules (security, compute, database, ALB). These outputs enable
# module composition and dependency management.
# =============================================================================

output "vpc_id" {
  description = "The unique identifier of the VPC. Required by security groups and other VPC-scoped resources."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs. These subnets are used for resources that need direct internet access, such as the Application Load Balancer and Bastion host."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of private application subnet IDs. These subnets host EC2 instances running the application containers. Instances here can access the internet via NAT Gateway but cannot receive unsolicited inbound traffic."
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of private database subnet IDs. These subnets host RDS instances with no internet access. Used by the database module to create the DB subnet group."
  value       = aws_subnet.private_db[*].id
}