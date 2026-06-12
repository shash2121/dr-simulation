# RDS Module - Main Configuration

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  count       = var.create_security_group ? 1 : 0
  name        = "${var.db_identifier}-sg"
  description = "Security group for RDS instance ${var.db_identifier}"
  vpc_id      = var.vpc_id

  # Allow database access on configured port
  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Database access"
  }

  # Allow cross-region replication access
  dynamic "ingress" {
    for_each = length(var.cross_region_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = var.cross_region_cidr_blocks
      description = "Cross-region replication access"
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.db_identifier}-rds-sg"
    }
  )
}

# RDS DB Parameter Group (for MySQL replication)
resource "aws_db_parameter_group" "this" {
  count  = var.engine == "mysql" && !var.is_replica ? 1 : 0
  name   = "${var.db_identifier}-pg"
  family = "${var.engine}${var.engine_version}"

  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  tags = merge(var.tags, { Name = "${var.db_identifier}-pg" })
}

# RDS Instance
resource "aws_db_instance" "rds_instance" {
  identifier              = var.db_identifier
  allocated_storage       = var.allocated_storage
  storage_type            = var.storage_type
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  db_name                 = var.is_replica ? null : var.db_name
  username                = var.is_replica ? null : var.username
  password                = var.is_replica ? null : var.password
  port                    = var.port
  db_subnet_group_name    = var.db_subnet_group_name
  vpc_security_group_ids  = var.create_security_group ? [aws_security_group.rds_sg[0].id] : var.vpc_security_group_ids
  parameter_group_name    = var.engine == "mysql" && !var.is_replica ? aws_db_parameter_group.this[0].name : null
  skip_final_snapshot     = var.skip_final_snapshot
  publicly_accessible     = var.publicly_accessible
  backup_retention_period = var.backup_retention_period
  storage_encrypted       = var.storage_encrypted

  # Replica configuration
  replicate_source_db = var.is_replica ? var.source_db_arn : null

  tags = merge(
    var.tags,
    {
      Name = "${var.db_identifier}-rds-instance"
    }
  )
}
