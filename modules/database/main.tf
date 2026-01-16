# =============================================================================
# DATABASE MODULE
# =============================================================================
# This module provisions a managed PostgreSQL database using Amazon RDS.
# RDS provides automated backups, patching, and high availability options.
#
# Security Features:
#   - Deployed in private subnets (no public internet access)
#   - Protected by security group (only accessible from app tier)
#   - Encrypted at rest (can be enabled)
#   - SSL/TLS encryption in transit (enforced via connection string)
#
# High Availability:
#   - Can be configured for Multi-AZ deployment (not enabled in this config)
#   - Automated backups enabled by default
# =============================================================================

# -----------------------------------------------------------------------------
# DATABASE SUBNET GROUP
# -----------------------------------------------------------------------------
# A DB subnet group is a collection of subnets that you designate for your
# RDS instances. RDS requires at least two subnets in different Availability
# Zones for high availability and failover capabilities.
#
# The subnets must be private (no internet gateway route) for security.
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  # Name must be lowercase and cannot contain spaces
  name       = lower(trimspace("${var.project_name}-db-subnet-group"))
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# -----------------------------------------------------------------------------
# RDS ENGINE VERSION DATA SOURCE
# -----------------------------------------------------------------------------
# Dynamically fetches the latest available PostgreSQL engine version.
# This ensures we always use the latest patched version within the major
# version (16.x) without hardcoding specific minor versions.
#
# Benefits:
#   - Automatic security patches
#   - Latest features and performance improvements
#   - No manual version updates required
# -----------------------------------------------------------------------------
data "aws_rds_engine_version" "postgres" {
  engine  = "postgres"
  version = "16" # Major version - Terraform finds latest minor version
  latest  = true # Ensures we get the latest patch version
}

# -----------------------------------------------------------------------------
# RDS POSTGRESQL INSTANCE
# -----------------------------------------------------------------------------
# Creates a managed PostgreSQL database instance. RDS handles:
#   - Automated backups
#   - Software patching
#   - Monitoring and alerting
#   - Point-in-time recovery
# -----------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  # Storage configuration
  # 20 GB is the minimum for gp3 storage type
  # Adjust based on your data requirements
  allocated_storage = 20
  storage_type      = "gp3" # General Purpose SSD (gp3) - modern, faster, cheaper than gp2

  # Database configuration
  db_name = "myappdb" # Initial database name
  engine  = data.aws_rds_engine_version.postgres.engine
  # Use the dynamically fetched version for latest patches
  engine_version = data.aws_rds_engine_version.postgres.version
  instance_class = "db.t3.micro" # Instance size - adjust based on workload

  # Authentication
  username = var.db_username
  password = var.db_password # Marked as sensitive in variables

  # Network configuration
  # Database must be in private subnets for security
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]

  # Security settings
  # CRITICAL: Never set this to true in production
  # Public access exposes the database to the internet
  publicly_accessible = false

  # Backup and snapshot settings
  # WARNING: Setting skip_final_snapshot to true means no backup is created
  # when the database is deleted. For production, set this to false and
  # specify a final_snapshot_identifier.
  skip_final_snapshot = true

  # Additional considerations for production:
  #   - backup_retention_period = 7 (days)
  #   - backup_window = "03:00-04:00" (maintenance window)
  #   - maintenance_window = "mon:04:00-mon:05:00"
  #   - multi_az = true (for high availability)
  #   - storage_encrypted = true (encryption at rest)
  #   - enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${var.project_name}-db"
  }
}