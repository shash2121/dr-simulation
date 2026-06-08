# Redis Security Group
resource "aws_security_group" "redis_sg" {
  name        = "${var.redis_identifier}-sg"
  description = "Security group for Redis cluster ${var.redis_identifier}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Redis access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.redis_identifier}-sg"
  })
}

# Redis Subnet Group
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "${var.redis_identifier}-subnet-group"
  description = "Subnet group for Redis cluster ${var.redis_identifier}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.redis_identifier}-subnet-group"
  })
}

# Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = var.redis_identifier
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.instance_type
  port                 = var.port
  parameter_group_name = var.parameter_group_name
  num_cache_nodes      = 1
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
  apply_immediately    = var.apply_immediately

  lifecycle {
    ignore_changes = [
      engine_version,
    ]
  }

  tags = merge(var.tags, {
    Name = var.redis_identifier
  })
}
