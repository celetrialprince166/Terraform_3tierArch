# =============================================================================
# SECURITY MODULE OUTPUTS
# =============================================================================
# Outputs expose security group IDs that are required by other modules.
# Security groups are referenced by:
#   - ALB module: needs alb_sg_id
#   - Compute module: needs bastion_sg_id and app_sg_id
#   - Database module: needs db_sg_id
# =============================================================================

output "alb_sg_id" {
  description = "Security group ID for the Application Load Balancer. This security group allows HTTP traffic from the internet."
  value       = aws_security_group.alb_sg.id
}

output "bastion_sg_id" {
  description = "Security group ID for the Bastion host. This security group allows SSH access from a specific IP address only."
  value       = aws_security_group.bastion_sg.id
}

output "app_sg_id" {
  description = "Security group ID for application servers. This security group allows HTTP traffic from the ALB and SSH from the Bastion host."
  value       = aws_security_group.app_sg.id
}

output "db_sg_id" {
  description = "Security group ID for the RDS database. This security group allows PostgreSQL connections from application servers only."
  value       = aws_security_group.db_sg.id
}