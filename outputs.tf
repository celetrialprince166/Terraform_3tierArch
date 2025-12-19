# =============================================================================
# ROOT MODULE OUTPUTS
# =============================================================================
# This file defines the outputs exposed by the root Terraform module.
# Outputs provide important information about created resources that may
# be needed for:
#   - Application configuration
#   - Manual operations and troubleshooting
#   - Integration with other systems
#   - Documentation and runbooks
# =============================================================================

# -----------------------------------------------------------------------------
# DATABASE CONNECTION INFORMATION
# -----------------------------------------------------------------------------
# These outputs provide connection details for the RDS PostgreSQL database.
# Use these values to configure database clients or connection strings.
# -----------------------------------------------------------------------------

output "rds_hostname" {
  description = "The hostname (DNS name) of the RDS PostgreSQL instance. Use this for database connections."
  value       = module.database.db_instance_address
}

output "rds_port" {
  description = "The port number on which the RDS instance is listening. Default is 5432 for PostgreSQL."
  value       = module.database.db_port
}

output "rds_endpoint" {
  description = "The full endpoint (hostname:port) of the RDS instance. This is the complete connection endpoint for database clients."
  value       = module.database.db_instance_endpoint
}

# -----------------------------------------------------------------------------
# BASTION HOST ACCESS INFORMATION
# -----------------------------------------------------------------------------
# The Bastion host (jump server) provides secure SSH access to private
# EC2 instances. These outputs help you connect to the Bastion.
# -----------------------------------------------------------------------------

output "SSH_COMMAND_BASTION" {
  description = "Pre-formatted SSH command to connect to the Bastion host. Copy and paste this command in your terminal after ensuring the private key has correct permissions (chmod 400)."
  value       = "ssh -i ${module.compute.key_path} ec2-user@${module.compute.bastion_public_ip}"
}

output "JUMP_HINT" {
  description = "Instructions for accessing private EC2 instances through the Bastion host. After connecting to the Bastion, use the same private key to SSH into private instances using their private IP addresses."
  value       = "Once on Bastion, use the same .pem key to connect to private IPs in the EC2 Console."
}

# -----------------------------------------------------------------------------
# APPLICATION SERVER INFORMATION
# -----------------------------------------------------------------------------
# Information about the application servers running in private subnets.
# These IPs can be used for troubleshooting or direct connections
# (via Bastion host).
# -----------------------------------------------------------------------------

output "APP_SERVER_PRIVATE_IP" {
  description = "List of private IP addresses of EC2 instances in the Auto Scaling Group. These instances run the application containers in private subnets. Access them via the Bastion host."
  value       = module.compute.app_server_private_ips
}

output "alb_endpoint" {
  value = module.alb.alb_dns_name
}