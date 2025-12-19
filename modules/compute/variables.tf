# =============================================================================
# COMPUTE MODULE VARIABLES
# =============================================================================
# Input variables for the compute module. These define instance configuration,
# network placement, security, scaling parameters, and runtime environment
# variables that are injected into application containers.
# =============================================================================

# -----------------------------------------------------------------------------
# BASIC CONFIGURATION
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for both Bastion and Application servers. Choose based on workload requirements (e.g., 't3.micro', 't3.small', 't3.medium')."
  type        = string
}

variable "ami_ssm_path" {
  description = "AWS Systems Manager Parameter Store path for the latest Amazon Linux AMI. This ensures we always use the latest patched AMI without hardcoding AMI IDs."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair to use for SSH access. Alternatively, this module can generate a new key pair automatically."
  type        = string
}

# -----------------------------------------------------------------------------
# NETWORKING CONFIGURATION
# -----------------------------------------------------------------------------
variable "public_subnet_id" {
  description = "ID of the public subnet where the Bastion host will be deployed. The Bastion must be in a public subnet to receive SSH connections from the internet."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "List of private application subnet IDs where EC2 instances will be launched. These should span multiple Availability Zones for high availability."
  type        = list(string)
}

# -----------------------------------------------------------------------------
# SECURITY CONFIGURATION
# -----------------------------------------------------------------------------
variable "bastion_sg_id" {
  description = "Security group ID for the Bastion host. This security group should allow SSH (port 22) from a specific IP address only."
  type        = string
}

variable "app_sg_id" {
  description = "Security group ID for application servers. This security group should allow HTTP (port 80) from the ALB and SSH (port 22) from the Bastion host."
  type        = string
}

# -----------------------------------------------------------------------------
# LOAD BALANCER INTEGRATION
# -----------------------------------------------------------------------------
variable "alb_target_group_arn" {
  description = "ARN of the Application Load Balancer target group. EC2 instances launched by the Auto Scaling Group will be automatically registered with this target group."
  type        = string
}

# -----------------------------------------------------------------------------
# AUTO SCALING CONFIGURATION
# -----------------------------------------------------------------------------
variable "asg_desired_cap" {
  description = "Desired number of EC2 instances in the Auto Scaling Group. The ASG will attempt to maintain this number of instances."
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances the Auto Scaling Group can scale up to. This provides a cost control mechanism."
  type        = number
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances the Auto Scaling Group must maintain. This ensures availability even during low demand periods."
  type        = number
}

# -----------------------------------------------------------------------------
# DATABASE CONFIGURATION
# -----------------------------------------------------------------------------
variable "db_endpoint" {
  description = "RDS database endpoint (hostname:port). Used to construct database connection strings that are injected into application containers."
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS database. Used to construct database connection strings."
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS database. Used to construct database connection strings. This value is marked as sensitive."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the database to connect to. Used to construct database connection strings."
  type        = string
}

variable "database_url" {
  description = "Complete database connection URL for the application. This is the primary connection string used by the application to connect to PostgreSQL. Format: 'postgresql://user:password@host:port/database?sslmode=require'"
  type        = string
  sensitive   = true
}

variable "direct_url" {
  description = "Direct database connection URL for Prisma ORM or other tools that require a separate direct connection. Format: 'postgresql://user:password@host:port/database?sslmode=require'"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# DOCKER HUB CONFIGURATION
# -----------------------------------------------------------------------------
variable "dockerhub_username" {
  description = "Docker Hub username for authenticating and pulling container images. Used by EC2 instances to log into Docker Hub."
  type        = string
  default     = "princeayiku"
}

variable "dockerhub_token" {
  description = "Docker Hub access token (not password) for authenticating with Docker Hub. Generate this from Docker Hub account settings. WARNING: This is sensitive and should be stored securely."
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# EXTERNAL SERVICE CREDENTIALS
# -----------------------------------------------------------------------------
# These variables store API keys and secrets for third-party services.
# They are injected as environment variables into Docker containers at runtime.
# -----------------------------------------------------------------------------

variable "clerk_secret_key" {
  description = "Clerk authentication service secret key. Used for backend authentication operations. This is sensitive and should be kept secure."
  type        = string
  sensitive   = true
}

variable "clerk_pub_key" {
  description = "Clerk authentication service publishable key. Used for frontend authentication operations. This key can be safely exposed in client-side code."
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