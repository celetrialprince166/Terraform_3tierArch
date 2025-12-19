# =============================================================================
# NETWORKING MODULE
# =============================================================================
# This module creates the foundational network infrastructure for a three-tier
# architecture. It provisions:
#   - VPC with DNS support
#   - Public subnets (for ALB and Bastion)
#   - Private application subnets (for EC2 instances)
#   - Private database subnets (for RDS)
#   - Internet Gateway (for public internet access)
#   - NAT Gateway (for private subnet outbound access)
#   - Route tables and associations
#
# Architecture Principles:
#   - Multi-AZ deployment for high availability
#   - Network isolation between tiers
#   - No direct internet access for database tier
# =============================================================================

# -----------------------------------------------------------------------------
# VPC (Virtual Private Cloud)
# -----------------------------------------------------------------------------
# The VPC is the isolated network environment where all AWS resources run.
# It provides network isolation from other AWS accounts and the public internet.
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  # CIDR block defines the IP address range for the entire VPC
  # Example: 10.0.0.0/16 provides 65,536 IP addresses
  cidr_block = var.vpc_cidr

  # Enable DNS hostnames: Allows EC2 instances to get DNS hostnames
  # (e.g., ip-10-0-1-5.ec2.internal)
  enable_dns_hostnames = true

  # Enable DNS support: Allows DNS resolution within the VPC
  # Required for RDS endpoint resolution and internal service discovery
  enable_dns_support = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# -----------------------------------------------------------------------------
# PUBLIC SUBNETS (Tier 1)
# -----------------------------------------------------------------------------
# Public subnets have direct internet access via Internet Gateway.
# These subnets host:
#   - Application Load Balancer (ALB) - receives traffic from internet
#   - Bastion Host - provides SSH access to private instances
#
# Security Note: Resources in public subnets are exposed to the internet
# and should be protected by security groups and proper access controls.
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Automatically assign public IP addresses to instances launched here
  # This is required for resources that need direct internet access
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
  }
}

# -----------------------------------------------------------------------------
# PRIVATE APPLICATION SUBNETS (Tier 2)
# -----------------------------------------------------------------------------
# Private subnets do NOT have direct internet access. Instances here:
#   - Can access the internet via NAT Gateway (outbound only)
#   - Cannot receive unsolicited inbound traffic from internet
#   - Host application servers (EC2 instances running Docker containers)
#
# This design provides an additional layer of security by hiding application
# servers from direct internet exposure.
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_app" {
  count = length(var.private_app_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Note: map_public_ip_on_launch is false by default (not set)
  # Instances in private subnets do not get public IPs

  tags = {
    Name = "${var.project_name}-private-app-${count.index + 1}"
  }
}

# -----------------------------------------------------------------------------
# PRIVATE DATABASE SUBNETS (Tier 3)
# -----------------------------------------------------------------------------
# Database subnets are the most isolated:
#   - No internet access (no NAT Gateway association)
#   - Only accessible from application tier via security groups
#   - Host RDS PostgreSQL instances
#
# This provides maximum security for sensitive data by ensuring databases
# are completely isolated from the internet.
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_db" {
  count = length(var.private_db_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-db-${count.index + 1}"
  }
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY (IGW)
# -----------------------------------------------------------------------------
# The Internet Gateway provides a gateway between the VPC and the public
# internet. It enables:
#   - Resources in public subnets to access the internet
#   - Internet users to access resources in public subnets (via public IPs)
#
# There is one IGW per VPC, and it is highly available by design.
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -----------------------------------------------------------------------------
# ELASTIC IP FOR NAT GATEWAY
# -----------------------------------------------------------------------------
# NAT Gateway requires a static public IP address (Elastic IP).
# This EIP is allocated from AWS's pool and remains constant even if the
# NAT Gateway is recreated.
#
# Note: EIPs incur charges when allocated but not attached to a running
# instance. The NAT Gateway uses this EIP.
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  # Domain must be "vpc" for VPC resources
  domain = "vpc"

  # Tags are inherited from provider default_tags
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# -----------------------------------------------------------------------------
# NAT GATEWAY
# -----------------------------------------------------------------------------
# NAT Gateway allows resources in private subnets to make outbound connections
# to the internet (e.g., downloading updates, pulling Docker images) while
# preventing inbound connections from the internet.
#
# Placement: Must be in a public subnet to access the Internet Gateway.
# Cost: NAT Gateways incur hourly charges and data processing fees.
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "nat" {
  # Static public IP address for the NAT Gateway
  allocation_id = aws_eip.nat.id

  # NAT Gateway must be in a public subnet to access the Internet Gateway
  subnet_id = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat"
  }

  # Explicit dependency ensures IGW exists before NAT Gateway is created
  # This prevents potential race conditions during infrastructure creation
  depends_on = [aws_internet_gateway.igw]
}

# -----------------------------------------------------------------------------
# PUBLIC ROUTE TABLE
# -----------------------------------------------------------------------------
# Route table defines how traffic is routed within the VPC.
# Public route table routes:
#   - All internet traffic (0.0.0.0/0) → Internet Gateway
#   - Local VPC traffic → stays within VPC
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route: Send all non-local traffic to the Internet Gateway
  # This enables public subnets to access the internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# -----------------------------------------------------------------------------
# PUBLIC ROUTE TABLE ASSOCIATIONS
# -----------------------------------------------------------------------------
# Associates public subnets with the public route table.
# This ensures instances in public subnets use the IGW for internet access.
# -----------------------------------------------------------------------------
resource "aws_route_table_association" "public" {
  count = length(var.public_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# PRIVATE ROUTE TABLE
# -----------------------------------------------------------------------------
# Private route table routes:
#   - All internet traffic (0.0.0.0/0) → NAT Gateway (outbound only)
#   - Local VPC traffic → stays within VPC
#
# This enables private subnets to make outbound connections (e.g., to Docker
# Hub, package repositories) while blocking inbound internet traffic.
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Default route: Send all non-local traffic to the NAT Gateway
  # This enables outbound internet access from private subnets
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# -----------------------------------------------------------------------------
# PRIVATE ROUTE TABLE ASSOCIATIONS
# -----------------------------------------------------------------------------
# Associates private application subnets with the private route table.
# This enables application servers to access the internet via NAT Gateway
# (e.g., for pulling Docker images, installing packages).
# -----------------------------------------------------------------------------
resource "aws_route_table_association" "private_app" {
  count = length(var.private_app_cidrs)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# DATABASE SUBNET ROUTING
# -----------------------------------------------------------------------------
# Database subnets are intentionally NOT associated with any route table
# that includes internet access. This means:
#   - No outbound internet access (maximum security)
#   - No inbound internet access (already blocked by being private)
#   - Only accessible from within the VPC (via security groups)
#
# This design follows the principle of least privilege: databases only
# need to communicate with application servers, not the internet.
# -----------------------------------------------------------------------------