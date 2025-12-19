project_name       = "3tier-iac"
vpc_cidr           = "10.0.0.0/16"
public_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_cidrs  = ["10.0.3.0/24", "10.0.4.0/24"]
private_db_cidrs   = ["10.0.5.0/24", "10.0.6.0/24"]
availability_zones = ["eu-west-1a", "eu-west-1b"]
region             = "eu-west-1" # Or your preferred region
my_ip              = "0.0.0.0/0" # REPLACE THIS with your actual IP for security!
# Compute Specs
instance_type      = "t3.micro"
ami_ssm_path       = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
key_name = "teir_3key"
db_password = "Testdbpass"
db_username = "Testdbuser"

# --- CLERK AUTHENTICATION ---
clerk_secret_key = "sk_test_1JmmGgtIqwYNkUmEu3NY33mQ1s0pqJd6d9R5iqTRWJ"
clerk_pub_key    = "pk_test_cHJvbXB0LWFhcmR2YXJrLTMyLmNsZXJrLmFjY291bnRzLmRldiQ"

# --- PAYSTACK PAYMENT GATEWAY ---
paystack_public_key = "pk_test_cfe48b571b61246b1fddda8e7a144c51dbf16069"
paystack_key        = "sk_test_402c5b61c47453af64b3334c35bb1b31d3e7b7ba"

# --- EXTERNAL API CONFIGURATION ---
