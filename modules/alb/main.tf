# =============================================================================
# APPLICATION LOAD BALANCER MODULE
# =============================================================================
# This module creates an Application Load Balancer (ALB) that distributes
# incoming HTTP traffic across multiple EC2 instances in the application tier.
#
# ALB Features:
#   - Health checks to route traffic only to healthy instances
#   - Automatic traffic distribution across Availability Zones
#   - Integration with Auto Scaling Groups
#   - SSL/TLS termination (can be configured with ACM certificates)
#
# Architecture:
#   Internet → ALB (public subnets) → Target Group → EC2 Instances (private subnets)
# =============================================================================

# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# -----------------------------------------------------------------------------
# The ALB is a Layer 7 (application layer) load balancer that:
#   - Distributes traffic based on content (HTTP/HTTPS)
#   - Performs health checks on target instances
#   - Automatically routes traffic away from unhealthy instances
#   - Provides a single DNS name for the application
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # Public-facing ALB (receives traffic from internet)
  load_balancer_type = "application" # Layer 7 load balancer (vs Network LB which is Layer 4)

  # Security group controls what traffic can reach the ALB
  security_groups = [var.alb_sg_id]

  # ALB must be in public subnets to receive internet traffic
  # Subnets should span multiple Availability Zones for high availability
  subnets = var.public_subnet_ids

  # Additional considerations for production:
  #   - enable_deletion_protection = true (prevents accidental deletion)
  #   - enable_http2 = true (HTTP/2 support)
  #   - enable_cross_zone_load_balancing = true (distribute across AZs)

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# -----------------------------------------------------------------------------
# TARGET GROUP
# -----------------------------------------------------------------------------
# A target group defines which EC2 instances receive traffic from the ALB.
# The ALB performs health checks on targets and only routes traffic to
# healthy instances.
#
# Health Check Process:
#   1. ALB sends HTTP request to health check path
#   2. If instance responds with configured status code → healthy
#   3. If instance fails health checks → removed from rotation
#   4. Traffic is automatically rerouted to remaining healthy instances
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.project_name}-target-group"
  port     = var.app_port # Port on which targets receive traffic (typically 80)
  protocol = "HTTP"       # Application protocol (HTTP or HTTPS)
  vpc_id   = var.vpc_id   # Target group is VPC-scoped

  # Health check configuration
  # The ALB periodically checks the health of registered targets
  health_check {
    # Path to check (root path is common, but can be a dedicated health endpoint)
    path = "/"

    # How often to check (in seconds)
    # 30 seconds is a good balance between responsiveness and overhead
    interval = 30

    # Timeout for health check request (in seconds)
    # Should be less than the interval
    timeout = 5

    # Number of consecutive successful checks required to mark target as healthy
    # Higher values reduce false positives but increase time to detect recovery
    healthy_threshold = 3

    # Number of consecutive failed checks required to mark target as unhealthy
    # Lower values detect failures faster but may cause false positives
    unhealthy_threshold = 2

    # HTTP status code that indicates a healthy target
    # 200 OK is standard, but can be configured for custom health endpoints
    matcher = "200"
  }

  # Additional considerations:
  #   - deregistration_delay: Time to wait before deregistering unhealthy target
  #   - stickiness: Enable session stickiness if needed
  #   - target_type: "instance" (default) or "ip" for containers
}

# -----------------------------------------------------------------------------
# ALB LISTENER
# -----------------------------------------------------------------------------
# A listener checks for connection requests using the specified protocol and port.
# Think of it as the "ear" of the load balancer - it listens for incoming traffic
# and forwards it to the target group based on rules.
#
# In this configuration:
#   - Listens on port 80 (HTTP)
#   - Forwards all traffic to the application target group
#
# Production Recommendation:
#   - Add a second listener on port 443 (HTTPS)
#   - Configure SSL certificate using AWS Certificate Manager (ACM)
#   - Redirect HTTP (port 80) to HTTPS (port 443) for security
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action: forward all traffic to the target group
  # Additional rules can be added for path-based or host-based routing
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  # Example of HTTPS listener (commented out - requires ACM certificate):
  # resource "aws_lb_listener" "https" {
  #   load_balancer_arn = aws_lb.main.arn
  #   port              = "443"
  #   protocol          = "HTTPS"
  #   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  #   certificate_arn   = aws_acm_certificate.example.arn
  #
  #   default_action {
  #     type             = "forward"
  #     target_group_arn = aws_lb_target_group.app_tg.arn
  #   }
  # }
}