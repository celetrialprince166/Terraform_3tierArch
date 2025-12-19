# =============================================================================
# SECURITY MODULE
# =============================================================================
# This module implements a defense-in-depth security model using AWS Security
# Groups. Security Groups act as stateful firewalls that control inbound and
# outbound traffic at the instance level.
#
# Security Architecture:
#   - Each tier has its own security group
#   - Rules follow the principle of least privilege
#   - Security groups reference each other (not IP addresses) for flexibility
#   - Inbound rules are restrictive, outbound rules are permissive
#
# Traffic Flow:
#   Internet → ALB (port 80) → App Servers (port 80) → Database (port 5432)
#   Admin → Bastion (port 22) → App Servers (port 22)
# =============================================================================

# -----------------------------------------------------------------------------
# ALB SECURITY GROUP (Public Tier)
# -----------------------------------------------------------------------------
# Security group for the Application Load Balancer.
# The ALB is the entry point for all public internet traffic.
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer. Allows HTTP traffic from internet and forwards to application tier."
  vpc_id      = var.vpc_id

  # ---------------------------------------------------------------------------
  # INBOUND RULES
  # ---------------------------------------------------------------------------
  # Allow HTTP traffic from anywhere on the internet
  # This enables users to access the application via the ALB
  # Note: For production, consider adding HTTPS (port 443) and redirecting
  # HTTP to HTTPS for enhanced security
  # ---------------------------------------------------------------------------
  ingress {
    description = "Allow HTTP traffic from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ---------------------------------------------------------------------------
  # OUTBOUND RULES
  # ---------------------------------------------------------------------------
  # Allow all outbound traffic so the ALB can:
  #   - Forward requests to application servers
  #   - Perform health checks
  #   - Access AWS services (CloudWatch, etc.)
  # ---------------------------------------------------------------------------
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# BASTION HOST SECURITY GROUP (Public Tier)
# -----------------------------------------------------------------------------
# Security group for the Bastion (jump server) host.
# The Bastion provides secure SSH access to private EC2 instances.
# -----------------------------------------------------------------------------
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for Bastion host. Allows SSH access from a specific IP address only."
  vpc_id      = var.vpc_id

  # ---------------------------------------------------------------------------
  # INBOUND RULES
  # ---------------------------------------------------------------------------
  # Restrict SSH access to a specific IP address (your IP)
  # This is a critical security measure: only authorized administrators
  # can access the Bastion host, which in turn provides access to private
  # instances.
  #
  # Security Best Practice: Never use 0.0.0.0/0 for SSH access in production
  # ---------------------------------------------------------------------------
  ingress {
    description = "Allow SSH access from specific IP address only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # Restricted to your specific IP for security
  }

  # ---------------------------------------------------------------------------
  # OUTBOUND RULES
  # ---------------------------------------------------------------------------
  # Allow all outbound traffic so the Bastion can:
  #   - SSH into private instances
  #   - Download updates and packages
  #   - Access AWS services
  # ---------------------------------------------------------------------------
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# -----------------------------------------------------------------------------
# APPLICATION SECURITY GROUP (Private Tier)
# -----------------------------------------------------------------------------
# Security group for EC2 instances running the application containers.
# These instances are in private subnets and should only receive traffic
# from the ALB (for application requests) and the Bastion (for SSH access).
# -----------------------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for application servers. Allows HTTP from ALB and SSH from Bastion only."
  vpc_id      = var.vpc_id

  # ---------------------------------------------------------------------------
  # INBOUND RULES
  # ---------------------------------------------------------------------------
  # Rule 1: Allow HTTP traffic ONLY from the ALB security group
  # This ensures application servers only receive traffic that has been
  # routed through the load balancer, not direct internet traffic.
  # Using security group references (not IP addresses) makes the rules
  # dynamic and resilient to IP changes.
  # ---------------------------------------------------------------------------
  ingress {
    description     = "Allow HTTP traffic from Application Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Rule 2: Allow SSH traffic ONLY from the Bastion security group
  # This enables administrators to SSH into application servers through
  # the Bastion host, following the jump server pattern.
  # ---------------------------------------------------------------------------
  ingress {
    description     = "Allow SSH access from Bastion host only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # ---------------------------------------------------------------------------
  # OUTBOUND RULES
  # ---------------------------------------------------------------------------
  # Allow all outbound traffic so application servers can:
  #   - Connect to the database
  #   - Pull Docker images from Docker Hub
  #   - Download packages and updates
  #   - Make API calls to external services
  # ---------------------------------------------------------------------------
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# -----------------------------------------------------------------------------
# DATABASE SECURITY GROUP (Private Tier)
# -----------------------------------------------------------------------------
# Security group for RDS PostgreSQL database instances.
# This is the most restrictive security group, allowing access only from
# the application tier.
# -----------------------------------------------------------------------------
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for RDS database. Allows PostgreSQL connections from application tier only."
  vpc_id      = var.vpc_id

  # ---------------------------------------------------------------------------
  # INBOUND RULES
  # ---------------------------------------------------------------------------
  # Allow PostgreSQL connections ONLY from the application security group
  # Port 5432 is the default PostgreSQL port.
  # This ensures the database is only accessible by application servers,
  # not by the internet, Bastion, or any other resources.
  # ---------------------------------------------------------------------------
  ingress {
    description     = "Allow PostgreSQL connections from application servers"
    from_port       = 5432 # Default PostgreSQL port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # ---------------------------------------------------------------------------
  # OUTBOUND RULES
  # ---------------------------------------------------------------------------
  # Allow all outbound traffic (though databases typically don't initiate
  # connections). This is permissive but necessary for some database
  # operations and AWS service integrations.
  # ---------------------------------------------------------------------------
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}