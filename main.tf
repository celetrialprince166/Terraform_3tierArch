# =============================================================================
# ROOT MODULE - THREE-TIER AWS ARCHITECTURE
# =============================================================================
# This file orchestrates the deployment of a production-ready three-tier
# architecture on AWS using Terraform modules. The architecture follows
# industry best practices for security, scalability, and high availability.
#
# Architecture Overview:
#   Tier 1 (Public):  Application Load Balancer (ALB) and Bastion Host
#   Tier 2 (Private): Application Servers (EC2 in Auto Scaling Group)
#   Tier 3 (Private): Database Layer (RDS PostgreSQL)
#
# Module Dependencies:
#   1. Networking → Foundation for all other resources
#   2. Security → Depends on Networking (VPC ID)
#   3. Database → Depends on Networking (subnets) and Security (SG)
#   4. ALB → Depends on Networking (subnets) and Security (SG)
#   5. Compute → Depends on all previous modules
# =============================================================================

# -----------------------------------------------------------------------------
# MODULE 1: NETWORKING
# -----------------------------------------------------------------------------
# Creates the foundational network infrastructure:
# - VPC with public and private subnets across multiple AZs
# - Internet Gateway for public internet access
# - NAT Gateway for private subnet outbound connectivity
# - Route tables and associations for proper traffic routing
# -----------------------------------------------------------------------------
module "networking" {
  source             = "./modules/networking"
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_cidrs       = var.public_cidrs
  private_app_cidrs  = var.private_app_cidrs
  private_db_cidrs   = var.private_db_cidrs
  availability_zones = var.availability_zones
}

# -----------------------------------------------------------------------------
# MODULE 2: SECURITY
# -----------------------------------------------------------------------------
# Implements defense-in-depth security model with Security Groups:
# - ALB Security Group: Allows HTTP (port 80) from internet
# - Bastion Security Group: Allows SSH (port 22) from specific IP only
# - App Security Group: Allows traffic from ALB and SSH from Bastion
# - Database Security Group: Allows PostgreSQL (port 5432) from App tier only
#
# Security Principle: Least privilege access - each tier can only communicate
# with the tier directly above or below it in the architecture.
# -----------------------------------------------------------------------------
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  # VPC ID is required to create security groups within the VPC
  vpc_id = module.networking.vpc_id
  # Restrict SSH access to Bastion to your specific IP for enhanced security
  my_ip = var.my_ip
}

# -----------------------------------------------------------------------------
# MODULE 3: DATABASE
# -----------------------------------------------------------------------------
# Provisions managed PostgreSQL database using Amazon RDS:
# - Deployed in private subnets (no public internet access)
# - Multi-AZ capable for high availability
# - Encrypted at rest and in transit
# - Accessible only from application tier via security group rules
#
# Note: Database credentials are marked as sensitive in variables.tf
# -----------------------------------------------------------------------------
module "database" {
  source       = "./modules/database"
  project_name = var.project_name
  # Database must be in private subnets for security isolation
  private_db_subnet_ids = module.networking.private_db_subnet_ids
  # Security group restricts access to application tier only
  db_sg_id    = module.security.db_sg_id
  db_username = var.db_username
  db_password = var.db_password
}

# -----------------------------------------------------------------------------
# MODULE 4: APPLICATION LOAD BALANCER
# -----------------------------------------------------------------------------
# Creates a public-facing ALB to distribute incoming traffic:
# - Distributes HTTP traffic across healthy EC2 instances
# - Provides health checks to route traffic only to healthy targets
# - Enables horizontal scaling by adding/removing instances behind the ALB
# - Serves as the single entry point for external users
# -----------------------------------------------------------------------------
module "alb" {
  source       = "./modules/alb"
  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
  # ALB must be in public subnets to receive internet traffic
  public_subnet_ids = module.networking.public_subnet_ids
  # Security group allows HTTP traffic from internet
  alb_sg_id = module.security.alb_sg_id
}

# -----------------------------------------------------------------------------
# MODULE 5: COMPUTE
# -----------------------------------------------------------------------------
# Manages compute resources for the application tier:
# - Bastion Host: Secure SSH jump server in public subnet
# - Auto Scaling Group: Manages EC2 instances in private subnets
# - Launch Template: Defines instance configuration and user data script
# - Dynamic Configuration: Injects database connection strings at runtime
#
# Key Features:
#   - Auto-scaling based on demand (min: 1, desired: 2, max: 3)
#   - Docker container deployment via user_data script
#   - Environment variables injected securely from Terraform variables
#   - Integration with ALB target group for load distribution
# -----------------------------------------------------------------------------
module "compute" {
  source        = "./modules/compute"
  project_name  = var.project_name
  instance_type = var.instance_type
  ami_ssm_path  = var.ami_ssm_path
  # Bastion host in first public subnet for SSH access
  public_subnet_id = module.networking.public_subnet_ids[0]
  # Application servers in private subnets for security
  private_app_subnet_ids = module.networking.private_app_subnet_ids
  bastion_sg_id          = module.security.bastion_sg_id
  app_sg_id              = module.security.app_sg_id
  key_name               = var.key_name
  # Register instances with ALB target group for load balancing
  alb_target_group_arn = module.alb.target_group_arn

  # ---------------------------------------------------------------------------
  # DYNAMIC DATABASE CONNECTION CONFIGURATION
  # ---------------------------------------------------------------------------
  # These values are dynamically constructed using the RDS endpoint created
  # by the database module. This ensures the application can connect to the
  # database without hardcoding connection strings.
  #
  # The connection strings use SSL mode 'require' to encrypt data in transit,
  # which is a security best practice for database connections.
  # ---------------------------------------------------------------------------
  db_endpoint = module.database.db_instance_endpoint
  db_username = var.db_username
  db_password = var.db_password
  db_name     = var.db_name

  # Direct URL for Prisma ORM direct database connections
  direct_url = "postgresql://${var.db_username}:${var.db_password}@${module.database.db_instance_endpoint}/${var.db_name}?sslmode=require"
  # Standard database URL for application connections
  database_url = "postgresql://${var.db_username}:${var.db_password}@${module.database.db_instance_endpoint}/${var.db_name}?sslmode=require"

  # ---------------------------------------------------------------------------
  # EXTERNAL SERVICE CREDENTIALS
  # ---------------------------------------------------------------------------
  # These credentials are passed to the EC2 instances via user_data script
  # and injected as environment variables into the Docker container.
  # They are never hardcoded in the application code, following the
  # 12-factor app methodology for configuration management.
  # ---------------------------------------------------------------------------
  dockerhub_username  = var.dockerhub_username
  dockerhub_token     = var.dockerhub_token
  clerk_secret_key    = var.clerk_secret_key
  clerk_pub_key       = var.clerk_pub_key
  paystack_key        = var.paystack_key
  paystack_public_key = var.paystack_public_key

  # ---------------------------------------------------------------------------
  # AUTO SCALING GROUP CONFIGURATION
  # ---------------------------------------------------------------------------
  # These values control the scaling behavior of the application tier:
  # - min_size: Minimum number of instances (ensures availability)
  # - desired_capacity: Target number of instances (normal operation)
  # - max_size: Maximum number of instances (cost control)
  #
  # Note: Consider implementing CloudWatch alarms and scaling policies
  # for automatic scaling based on CPU, memory, or request metrics.
  # ---------------------------------------------------------------------------
  asg_desired_cap = 2
  asg_max_size    = 3
  asg_min_size    = 1
}