# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================
# This file configures Terraform itself and the AWS provider.
# It ensures version consistency across team members and environments.
# =============================================================================

terraform {
  # ---------------------------------------------------------------------------
  # TERRAFORM VERSION CONSTRAINT
  # ---------------------------------------------------------------------------
  # Locking the Terraform version ensures all team members use compatible
  # versions, preventing issues from version differences. This is especially
  # important for CI/CD pipelines where consistency is critical.
  # ---------------------------------------------------------------------------
  required_version = ">= 1.0.0"

  # ---------------------------------------------------------------------------
  # PROVIDER VERSION CONSTRAINTS
  # ---------------------------------------------------------------------------
  # Define and lock provider versions to prevent unexpected breaking changes.
  # The ~> (pessimistic constraint) operator allows:
  #   - Patch version updates (6.0.0 → 6.0.1) automatically
  #   - Minor version updates (6.0.0 → 6.1.0) automatically
  #   - Blocks major version updates (6.x → 7.x) that may break compatibility
  # ---------------------------------------------------------------------------
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Allows 6.x updates, blocks 7.x
    }
  }
}

# =============================================================================
# AWS PROVIDER CONFIGURATION
# =============================================================================
# Configures how Terraform authenticates and interacts with AWS.
# Authentication is handled via:
#   - AWS CLI credentials (~/.aws/credentials)
#   - Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
#   - IAM roles (when running on EC2)
# =============================================================================

provider "aws" {
  # AWS region where resources will be created
  # All resources in this configuration will be deployed to this region
  region = var.region

  # ---------------------------------------------------------------------------
  # DEFAULT TAGS
  # ---------------------------------------------------------------------------
  # Default tags are automatically applied to ALL resources created by this
  # provider configuration. This is a best practice for:
  #   - Cost allocation and tracking
  #   - Resource organization and filtering
  #   - Compliance and governance
  #   - Automation and scripting
  #
  # These tags can be overridden on individual resources if needed.
  # ---------------------------------------------------------------------------
  default_tags {
    tags = {
      Project     = var.project_name # Identifies which project owns the resource
      Environment = "dev"            # Environment identifier (dev/staging/prod)
      ManagedBy   = "Terraform"      # Indicates Infrastructure as Code tool
    }
  }
}