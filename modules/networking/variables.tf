# =============================================================================
# NETWORKING MODULE VARIABLES
# =============================================================================
# Input variables for the networking module. These define the network topology
# including VPC CIDR blocks, subnet configurations, and availability zones.
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging. This ensures consistent naming across all networking resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., '10.0.0.0/16'). This defines the total IP address space available within the VPC. All subnets must be subsets of this CIDR block."
  type        = string
}

variable "public_cidrs" {
  description = "List of CIDR blocks for public subnets. These subnets have direct internet access via Internet Gateway. Typically, you'll have one public subnet per Availability Zone for high availability. Example: ['10.0.1.0/24', '10.0.2.0/24']"
  type        = list(string)
}

variable "private_app_cidrs" {
  description = "List of CIDR blocks for private application subnets. These subnets host EC2 instances and access the internet via NAT Gateway (outbound only). Should match the number of Availability Zones. Example: ['10.0.3.0/24', '10.0.4.0/24']"
  type        = list(string)
}

variable "private_db_cidrs" {
  description = "List of CIDR blocks for private database subnets. These subnets host RDS instances with no internet access for maximum security. Should match the number of Availability Zones. Example: ['10.0.5.0/24', '10.0.6.0/24']"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of Availability Zones where subnets will be created. Using multiple AZs ensures high availability and fault tolerance. The list length should match the number of CIDR blocks in each subnet type. Example: ['eu-west-1a', 'eu-west-1b']"
  type        = list(string)
}