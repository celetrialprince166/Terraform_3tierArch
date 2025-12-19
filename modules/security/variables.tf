# =============================================================================
# SECURITY MODULE VARIABLES
# =============================================================================
# Input variables for the security module. These define the VPC context and
# access restrictions for the Bastion host.
# =============================================================================

variable "project_name" {
  description = "Project name used for security group naming and tagging. Ensures consistent naming across all security resources."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where security groups will be created. Security groups are VPC-scoped resources and must belong to a specific VPC."
  type        = string
}

variable "my_ip" {
  description = "Your public IP address in CIDR notation (e.g., '1.2.3.4/32') for SSH access to the Bastion host. Use /32 for a single IP address. IMPORTANT: Update this value before deployment to restrict SSH access to your IP only. You can find your IP at https://whatismyipaddress.com/"
  type        = string
}