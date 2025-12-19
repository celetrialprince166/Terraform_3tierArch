# =============================================================================
# COMPUTE MODULE OUTPUTS
# =============================================================================
# Outputs expose important information about compute resources, including
# access information for the Bastion host and application server details.
# =============================================================================

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host. Use this IP address to SSH into the Bastion host, then from there SSH into private EC2 instances using their private IP addresses."
  value       = aws_instance.bastion.public_ip
}

output "key_path" {
  description = "Local filesystem path to the private key file (.pem) generated for SSH access. Use this key with chmod 400 permissions to connect to EC2 instances. Example: './project-key.pem'"
  value       = local_file.private_key.filename
}

output "app_server_private_ips" {
  description = "List of private IP addresses of EC2 instances in the Auto Scaling Group. These are the application servers running in private subnets. Access them via the Bastion host using these private IPs."
  value       = data.aws_instances.app_servers.private_ips
}