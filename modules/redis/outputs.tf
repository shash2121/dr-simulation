output "redis_id" {
  description = "The ID of the Redis cluster"
  value       = aws_elasticache_cluster.redis.id
}

output "redis_arn" {
  description = "The ARN of the Redis cluster"
  value       = aws_elasticache_cluster.redis.arn
}

output "redis_endpoint" {
  description = "The endpoint address of the Redis cluster"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "The port of the Redis cluster"
  value       = aws_elasticache_cluster.redis.port
}

output "security_group_id" {
  description = "The ID of the Redis security group"
  value       = aws_security_group.redis_sg.id
}

output "subnet_group_name" {
  description = "The name of the Redis subnet group"
  value       = aws_elasticache_subnet_group.redis_subnet_group.name
}
