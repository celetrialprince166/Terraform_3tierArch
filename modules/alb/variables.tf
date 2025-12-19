# =============================================================================
# ALB MODULE VARIABLES
# =============================================================================
# Input variables for the Application Load Balancer module. These define the
# network placement, security configuration, and target port for the ALB.
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the ALB will be created. The ALB must be in the same VPC as the target instances."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs where the ALB will be deployed. The ALB must span at least two Availability Zones for high availability. These subnets must be public (have internet gateway route) to receive internet traffic."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB. This security group should allow HTTP (port 80) and optionally HTTPS (port 443) traffic from the internet (0.0.0.0/0)."
  type        = string
}

variable "app_port" {
  description = "Port number on which the application servers are listening. This is the port the ALB will use to forward traffic to targets. Default is 80 (HTTP)."
  type        = number
  default     = 80
}