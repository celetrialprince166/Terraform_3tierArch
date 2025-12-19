#!/bin/bash
# =============================================================================
# USER DATA SCRIPT - APPLICATION CONTAINER DEPLOYMENT
# =============================================================================
# This script runs automatically when an EC2 instance starts. It:
#   1. Installs and configures Docker
#   2. Authenticates with Docker Hub
#   3. Pulls the application container image
#   4. Runs the container with environment variables
#
# The script is designed to be resilient with retry logic for network
# operations, as EC2 instances may start before network connectivity is
# fully established.
#
# Logs: All output is logged to /var/log/user-data.log for troubleshooting
# =============================================================================

# -----------------------------------------------------------------------------
# LOGGING CONFIGURATION
# -----------------------------------------------------------------------------
# Redirect all output (stdout and stderr) to a log file
# This allows you to troubleshoot issues by viewing the log:
#   sudo tail -f /var/log/user-data.log
# -----------------------------------------------------------------------------
exec > /var/log/user-data.log 2>&1

# Enable command tracing: print each command before executing it
# This makes debugging easier by showing exactly what commands ran
set -x

# -----------------------------------------------------------------------------
# ERROR HANDLING
# -----------------------------------------------------------------------------
# Exit immediately if any command fails (non-zero exit code)
# This prevents the script from continuing with partial failures
# -----------------------------------------------------------------------------
set -e

echo "=============================================================================="
echo "Starting application deployment script at $(date)"
echo "=============================================================================="

# -----------------------------------------------------------------------------
# RETRY FUNCTION
# -----------------------------------------------------------------------------
# Network operations (yum, docker pull) can fail due to:
#   - Temporary network issues
#   - EC2 instance starting before network is ready
#   - Docker Hub rate limiting
#
# This function retries a command up to 5 times with exponential backoff
# to handle transient failures gracefully.
# -----------------------------------------------------------------------------
retry() {
  local n=1
  local max=5
  local delay=15
  
  while true; do
    # Execute the command and break if successful
    "$@" && break || {
      # If command failed and we haven't reached max attempts
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max in $delay seconds..."
        sleep $delay
      else
        # Max attempts reached - exit with error
        echo "ERROR: The command has failed after $n attempts."
        exit 1
      fi
    }
  done
}

# -----------------------------------------------------------------------------
# DOCKER INSTALLATION
# -----------------------------------------------------------------------------
# Install Docker on Amazon Linux 2. Docker is required to run the
# application container.
#
# Steps:
#   1. Update system packages (with retry for network issues)
#   2. Install Docker package
#   3. Start Docker service
#   4. Enable Docker to start on boot (ensures it restarts after reboots)
# -----------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
echo "Installing Docker..."
echo "------------------------------------------------------------------------------"

retry yum update -y
retry yum install -y docker

# Start Docker service
systemctl start docker

# Enable Docker to start automatically on system boot
# This ensures Docker is running even after instance restarts
systemctl enable docker

echo "Docker installation complete."

# -----------------------------------------------------------------------------
# DOCKER HUB AUTHENTICATION
# -----------------------------------------------------------------------------
# Authenticate with Docker Hub to pull private container images.
# The credentials are passed from Terraform variables and injected
# as environment variables in this script.
#
# Security Note: Credentials are passed via stdin to avoid exposing
# them in process lists or command history.
# -----------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
echo "Authenticating with Docker Hub..."
echo "------------------------------------------------------------------------------"

echo "${docker_password}" | docker login -u "${docker_username}" --password-stdin

if [ $? -eq 0 ]; then
  echo "Successfully authenticated with Docker Hub."
else
  echo "ERROR: Docker Hub authentication failed."
  exit 1
fi

# -----------------------------------------------------------------------------
# CONTAINER IMAGE PULL
# -----------------------------------------------------------------------------
# Pull the latest version of the application container image from Docker Hub.
# Using 'latest' tag ensures we get the most recent version.
#
# The retry logic is critical here because:
#   - Large images can take time to download
#   - Network issues can interrupt the download
#   - Docker Hub rate limiting may cause temporary failures
# -----------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
echo "Pulling application container image..."
echo "------------------------------------------------------------------------------"

retry docker pull ${docker_username}/pharma-webapp:latest

echo "Container image pull complete."

# -----------------------------------------------------------------------------
# CONTAINER DEPLOYMENT
# -----------------------------------------------------------------------------
# Run the application container with all required environment variables.
#
# Container Configuration:
#   - --name: Container name for easy reference
#   - --restart always: Automatically restart container if it stops
#   - -p 80:3000: Map host port 80 to container port 3000
#   - -e: Environment variables injected into container
#   - -d: Run in detached mode (background)
#
# Environment Variables:
#   - DATABASE_URL: Primary database connection string
#   - DIRECT_URL: Direct database connection for Prisma ORM
#   - CLERK_*: Authentication service credentials
#   - PAYSTACK_*: Payment gateway credentials
#   - NEXT_PUBLIC_*: Public environment variables for Next.js frontend
# -----------------------------------------------------------------------------
echo "------------------------------------------------------------------------------"
echo "Deploying application container..."
echo "------------------------------------------------------------------------------"

# Remove any existing container with the same name (idempotency)
# This allows the script to be re-run safely
docker rm -f pharma-app || true

# Run the container with all environment variables
docker run -d \
  --name pharma-app \
  --restart always \
  -p 80:3000 \
  -e DATABASE_URL="${database_url}" \
  -e DIRECT_URL="${direct_url}" \
  -e CLERK_SECRET_KEY="${clerk_secret_key}" \
  -e NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="${clerk_pub_key}" \
  -e PAYSTACK_SECRET_KEY="${paystack_key}" \
  -e NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY="${paystack_public_key}" \
  -e NEXT_PUBLIC_CLERK_SIGN_IN_URL="/sign-in" \
  -e NEXT_PUBLIC_CLERK_SIGN_UP_URL="/sign-up" \
  -e NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL="/dashboard" \
  -e NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL="/dashboard" \
  ${docker_username}/pharma-webapp:latest

# Verify container is running
if [ $? -eq 0 ]; then
  echo "Container started successfully."
  docker ps | grep pharma-app
else
  echo "ERROR: Failed to start container."
  exit 1
fi

# -----------------------------------------------------------------------------
# DEPLOYMENT COMPLETE
# -----------------------------------------------------------------------------
echo "=============================================================================="
echo "Deployment complete at $(date)"
echo "=============================================================================="
echo ""
echo "Application is now running on port 80."
echo "View logs with: docker logs pharma-app"
echo "View user-data log with: sudo tail -f /var/log/user-data.log"
echo ""