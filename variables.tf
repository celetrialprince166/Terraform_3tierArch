# =============================================================================
# ROOT MODULE VARIABLES
# =============================================================================
# This file defines all input variables for the root Terraform module.
# Variables are organized by category: networking, compute, database, and
# external service credentials.
#
# Best Practices:
#   - All sensitive variables are marked with sensitive = true
#   - Variables include descriptions for documentation
#   - Default values are provided where appropriate
#   - Variable types are explicitly defined for validation
# =============================================================================

# -----------------------------------------------------------------------------
# PROJECT IDENTIFICATION
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Name of the project used for resource naming and tagging. This value is used as a prefix for all AWS resources."
  type        = string
}

variable "region" {
  description = "The AWS region where all resources will be deployed. Choose a region close to your users for lower latency."
  type        = string
}

# -----------------------------------------------------------------------------
# NETWORKING CONFIGURATION
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., '10.0.0.0/16'). This defines the IP address range for the entire VPC."
  type        = string
}

variable "public_cidrs" {
  description = "List of CIDR blocks for public subnets. These subnets have direct internet access via Internet Gateway. Typically one per Availability Zone."
  type        = list(string)
}

variable "private_app_cidrs" {
  description = "List of CIDR blocks for private application subnets. These subnets host EC2 instances and access internet via NAT Gateway."
  type        = list(string)
}

variable "private_db_cidrs" {
  description = "List of CIDR blocks for private database subnets. These subnets host RDS instances with no internet access for maximum security."
  type        = list(string)
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy resources across. Using multiple AZs ensures high availability and fault tolerance."
  type        = list(string)
}

# -----------------------------------------------------------------------------
# SECURITY CONFIGURATION
# -----------------------------------------------------------------------------
variable "my_ip" {
  description = "Your public IP address in CIDR format (e.g., '1.2.3.4/32') for SSH access to the Bastion host. Use /32 for a single IP address. IMPORTANT: Update this before deployment for security."
  type        = string
}

variable "key_name" {
  description = "Name of the AWS EC2 Key Pair to use for SSH access. This key pair must already exist in the specified AWS region."
  type        = string
}

# -----------------------------------------------------------------------------
# COMPUTE CONFIGURATION
# -----------------------------------------------------------------------------
variable "instance_type" {
  description = "EC2 instance type for both Bastion and Application servers (e.g., 't3.micro', 't3.small'). Choose based on workload requirements."
  type        = string
}

variable "ami_ssm_path" {
  description = "AWS Systems Manager Parameter Store path for the latest Amazon Linux AMI. This ensures we always use the latest patched AMI. Example: '/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2'"
  type        = string
}

# -----------------------------------------------------------------------------
# DATABASE CONFIGURATION
# -----------------------------------------------------------------------------
variable "db_username" {
  description = "Master username for the RDS PostgreSQL database. This should be a strong, unique username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL database. Must meet RDS password requirements (8+ characters, mixed case, numbers, special chars)."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the initial database created in the RDS instance. This is the database your application will connect to."
  type        = string
  default     = "myappdb"
}

# -----------------------------------------------------------------------------
# DOCKER HUB CONFIGURATION
# -----------------------------------------------------------------------------
variable "dockerhub_username" {
  description = "Docker Hub username for pulling private container images. Used by EC2 instances to authenticate with Docker Hub."
  type        = string
  default     = "princeayiku"
}

variable "dockerhub_token" {
  description = "Docker Hub access token (not password) for authenticating with Docker Hub. Generate this from Docker Hub account settings. WARNING: This is sensitive and should be stored in terraform.tfvars (which is gitignored)."
  type        = string
  sensitive   = true

}

# -----------------------------------------------------------------------------
# EXTERNAL SERVICE CREDENTIALS
# -----------------------------------------------------------------------------
# These variables store API keys and secrets for third-party services.
# They are injected as environment variables into the Docker container
# at runtime and should NEVER be hardcoded in application code.
# -----------------------------------------------------------------------------

variable "clerk_secret_key" {
  description = "Clerk authentication service secret key. Used for backend authentication operations. Keep this secret secure."
  type        = string
  sensitive   = true
}

variable "clerk_pub_key" {
  description = "Clerk authentication service publishable key. Used for frontend authentication operations. This key can be exposed in client-side code."
  type        = string
}

variable "paystack_key" {
  description = "Paystack payment gateway secret key. Used for processing payments on the backend. This is highly sensitive financial data."
  type        = string
  sensitive   = true
}

variable "paystack_public_key" {
  description = "Paystack payment gateway public key. Used for initializing payment transactions from the frontend."
  type        = string
}
