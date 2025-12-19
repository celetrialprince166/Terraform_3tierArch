# =============================================================================
# DATABASE MODULE OUTPUTS
# =============================================================================
# Outputs expose connection information for the RDS instance. These values
# are used by the compute module to construct database connection strings
# that are injected into application containers at runtime.
# =============================================================================

output "db_instance_endpoint" {
  description = "The complete connection endpoint (hostname:port) for the RDS instance. Use this value to construct database connection strings. Example: 'mydb.abc123.us-east-1.rds.amazonaws.com:5432'"
  value       = aws_db_instance.postgres.endpoint
}

output "db_instance_address" {
  description = "The hostname (DNS name) of the RDS instance. This is the hostname portion of the endpoint, without the port number."
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "The port number on which the database is listening. Default is 5432 for PostgreSQL. This value is used when constructing connection strings."
  value       = aws_db_instance.postgres.port
}