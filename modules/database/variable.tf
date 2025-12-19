# =============================================================================
# DATABASE MODULE VARIABLES
# =============================================================================
# Input variables for the database module. These define the network placement,
# security configuration, and authentication credentials for the RDS instance.
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "private_db_subnet_ids" {
  description = "List of private database subnet IDs where the RDS instance will be deployed. These subnets must be in at least two different Availability Zones for high availability."
  type        = list(string)
}

variable "db_sg_id" {
  description = "Security group ID that controls access to the RDS instance. This security group should allow PostgreSQL connections (port 5432) from the application tier only."
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance. This is the administrative user that can create databases and manage the instance. Choose a strong, unique username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance. Must meet RDS password requirements: 8-128 characters, must contain uppercase, lowercase, numbers, and special characters. This value is marked as sensitive and will not be displayed in Terraform output."
  type        = string
  sensitive   = true
}