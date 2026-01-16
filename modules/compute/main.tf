# =============================================================================
# COMPUTE MODULE
# =============================================================================
# This module manages all compute resources for the application:
#   - SSH Key Pair: For secure access to EC2 instances
#   - Bastion Host: Secure jump server for accessing private instances
#   - Launch Template: Defines EC2 instance configuration and startup script
#   - Auto Scaling Group: Manages EC2 instances with automatic scaling
#
# Key Features:
#   - Automatic AMI selection (latest Amazon Linux via SSM Parameter Store)
#   - Docker container deployment via user_data script
#   - Dynamic environment variable injection
#   - Integration with ALB for load distribution
#   - Multi-AZ deployment for high availability
# =============================================================================

# -----------------------------------------------------------------------------
# AMI DATA SOURCE
# -----------------------------------------------------------------------------
# Dynamically fetches the latest Amazon Linux 2 AMI ID from AWS Systems
# Manager Parameter Store. This ensures we always use the latest patched
# AMI without hardcoding AMI IDs (which change frequently and are region-specific).
#
# Benefits:
#   - Automatic security patches
#   - No manual AMI updates required
#   - Works across all AWS regions
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "linux_ami" {
  name = var.ami_ssm_path
}

# -----------------------------------------------------------------------------
# SSH KEY PAIR GENERATION
# -----------------------------------------------------------------------------
# Generates a new RSA SSH key pair for secure access to EC2 instances.
# The key pair consists of:
#   - Private key: Saved locally (keep this secure!)
#   - Public key: Uploaded to AWS for EC2 instances
#
# Security Notes:
#   - Private key is saved with 0400 permissions (read-only for owner)
#   - 4096-bit RSA provides strong security
#   - Key is generated fresh for each deployment (or reuse existing key)
# -----------------------------------------------------------------------------

# Generate the private key using TLS provider
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096 # 4096-bit key provides strong security
}

# Upload the public key to AWS
resource "aws_key_pair" "generated_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

# Save the private key to local filesystem for SSH access
# WARNING: This file contains sensitive credentials. Keep it secure!
# The key is saved in the root directory of the Terraform project.
resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${path.root}/${var.project_name}-key.pem"
  file_permission = "0400" # Read-only for owner (chmod 400)

  # Prevent the private key from being displayed in logs
  sensitive_content = true
}

# -----------------------------------------------------------------------------
# BASTION HOST (JUMP SERVER)
# -----------------------------------------------------------------------------
# The Bastion host provides secure SSH access to EC2 instances in private
# subnets. Instead of exposing private instances to the internet, you:
#   1. SSH to the Bastion (in public subnet)
#   2. From the Bastion, SSH to private instances using their private IPs
#
# Security Benefits:
#   - Private instances have no public IPs (not directly accessible)
#   - Single point of access (easier to monitor and secure)
#   - SSH access restricted to specific IP (via security group)
#
# Usage:
#   ssh -i key.pem ec2-user@<bastion-public-ip>
#   Then from Bastion: ssh -i key.pem ec2-user@<private-instance-ip>
# -----------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  # Use the latest Amazon Linux 2 AMI
  ami           = data.aws_ssm_parameter.linux_ami.value
  instance_type = var.instance_type

  # Bastion must be in a public subnet to receive SSH connections
  subnet_id = var.public_subnet_id

  # Security group restricts SSH access to specific IP
  vpc_security_group_ids = [var.bastion_sg_id]

  # Use the generated key pair for SSH access
  key_name = aws_key_pair.generated_key.key_name

  tags = {
    Name = "${var.project_name}-bastion"
  }

  # Optional: Consider adding an Elastic IP for a fixed public IP address
  # This makes it easier to connect without looking up the IP each time
}

# -----------------------------------------------------------------------------
# LAUNCH TEMPLATE
# -----------------------------------------------------------------------------
# A launch template defines the configuration for EC2 instances launched
# by the Auto Scaling Group. It includes:
#   - AMI and instance type
#   - Security groups
#   - User data script (runs on instance startup)
#   - Key pair for SSH access
#
# The user_data script is critical - it:
#   - Installs Docker
#   - Pulls the application container image
#   - Starts the container with environment variables
#   - Configures the application to connect to the database
# -----------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix = "${var.project_name}-app-"

  # Instance configuration
  image_id      = data.aws_ssm_parameter.linux_ami.value
  instance_type = var.instance_type
  key_name      = aws_key_pair.generated_key.key_name

  # Security group allows traffic from ALB and SSH from Bastion
  vpc_security_group_ids = [var.app_sg_id]

  # ---------------------------------------------------------------------------
  # USER DATA SCRIPT
  # ---------------------------------------------------------------------------
  # The user_data script runs automatically when the instance starts.
  # It is base64-encoded and passed to the instance.
  #
  # The script:
  #   1. Installs Docker
  #   2. Logs into Docker Hub
  #   3. Pulls the application container image
  #   4. Runs the container with environment variables
  #
  # Environment variables are injected from Terraform variables, ensuring
  # the application has access to:
  #   - Database connection strings
  #   - API keys (Clerk, Paystack)
  #   - Docker Hub credentials
  #
  # The templatefile() function allows us to pass variables into the script.
  # ---------------------------------------------------------------------------
  user_data = base64encode(
    templatefile("${path.module}/scripts/user_data.sh", {
      docker_username     = var.dockerhub_username
      docker_password     = var.dockerhub_token
      database_url        = var.database_url
      direct_url          = var.direct_url
      clerk_secret_key    = var.clerk_secret_key
      clerk_pub_key       = var.clerk_pub_key
      paystack_key        = var.paystack_key
      paystack_public_key = var.paystack_public_key
    })
  )

  # Additional considerations for production:
  #   - iam_instance_profile: IAM role for EC2 instances (for AWS API access)
  #   - monitoring: Enable detailed CloudWatch monitoring
  #   - ebs_optimized: Enable EBS optimization for better disk performance
}

# -----------------------------------------------------------------------------
# AUTO SCALING GROUP
# -----------------------------------------------------------------------------
# The Auto Scaling Group (ASG) manages a group of EC2 instances that run
# the application. It provides:
#   - Automatic scaling based on demand
#   - Health checks and automatic replacement of unhealthy instances
#   - Distribution across multiple Availability Zones
#   - Integration with the Application Load Balancer
#
# Scaling Behavior:
#   - Maintains desired_capacity instances
#   - Can scale up to max_size during high demand
#   - Can scale down to min_size during low demand
#   - Automatically replaces unhealthy instances
#
# Note: This configuration uses fixed capacity. For automatic scaling,
# add CloudWatch alarms and scaling policies based on CPU, memory, or
# request metrics.
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  # Capacity settings
  desired_capacity = var.asg_desired_cap # Target number of instances
  max_size         = var.asg_max_size    # Maximum instances (cost control)
  min_size         = var.asg_min_size    # Minimum instances (availability)

  # Network configuration
  # Instances are launched in private subnets across multiple AZs
  vpc_zone_identifier = var.private_app_subnet_ids

  # Load balancer integration
  # New instances are automatically registered with the ALB target group
  # This enables the ALB to route traffic to new instances immediately
  target_group_arns = [var.alb_target_group_arn]

  # Launch template reference
  # All instances use the same launch template configuration
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest" # Always use the latest version of the template
  }

  # Tags applied to all instances launched by the ASG
  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-server"
    propagate_at_launch = true # Tag is applied to each instance
  }

  # Additional considerations for production:
  #   - health_check_type = "ELB" (use ALB health checks, not just EC2)
  #   - health_check_grace_period = 300 (time before health checks start)
  #   - termination_policies = ["OldestInstance"] (which instances to terminate first)
  #   - protect_from_scale_in = true (for instances that should not be terminated)
}

# -----------------------------------------------------------------------------
# APP SERVER INSTANCES DATA SOURCE
# -----------------------------------------------------------------------------
# This data source queries AWS to find all EC2 instances that match the
# Auto Scaling Group's naming pattern. It's used to output the private IP
# addresses of application servers for troubleshooting and documentation.
#
# Note: This is a read-only query that doesn't create or modify resources.
# It depends on the ASG existing first, so we use depends_on to ensure
# proper ordering.
# -----------------------------------------------------------------------------
data "aws_instances" "app_servers" {
  # Only query instances that are currently running
  instance_state_names = ["running"]

  # Filter by the tag that the ASG applies to all instances
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-app-server"]
  }

  # Ensure the ASG exists before querying for instances
  # This prevents errors during initial deployment
  depends_on = [aws_autoscaling_group.app]
}
