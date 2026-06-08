output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.rds_instance.endpoint
}

output "db_instance_id" {
  description = "The ID of the RDS instance"
  value       = aws_db_instance.rds_instance.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.rds_instance.arn
}

output "db_instance_name" {
  description = "The name of the database"
  value       = aws_db_instance.rds_instance.db_name
}

output "db_instance_username" {
  description = "The username for the database"
  value       = aws_db_instance.rds_instance.username
  sensitive   = true
}

output "db_instance_port" {
  description = "The port on which the database accepts connections"
  value       = aws_db_instance.rds_instance.port
}

output "security_group_id" {
  description = "The ID of the RDS security group"
  value       = var.create_security_group ? aws_security_group.rds_sg[0].id : null
}

output "security_group_arn" {
  description = "The ARN of the RDS security group"
  value       = var.create_security_group ? aws_security_group.rds_sg[0].arn : null
}
