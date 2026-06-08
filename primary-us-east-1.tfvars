# ───────────── Region ─────────────
aws_region = "us-east-1"

# ───────────── Environment ─────────────
environment = "primary"
tags = {
  Project     = "DR-Simulation"
  Environment = "primary"
}

# ───────────── VPC / Networking ─────────────
vpc_cidr = "10.0.0.0/16"

# ───────────── EKS ─────────────
eks_cluster_version    = "1.35"
eks_node_instance_type = "m7i-flex.large"
eks_min_nodes          = 1
eks_max_nodes          = 3
eks_desired_nodes      = 2
eks_pod_sa_name        = "my-app-sa"

# ───────────── RDS (MySQL) ─────────────
rds_engine            = "mysql"
rds_engine_version    = "8.0"
rds_instance_class    = "db.t3.micro"
rds_allocated_storage = 20
rds_backup_retention_period = 0
rds_db_name           = "dummydb"
rds_username          = "admin"
rds_password          = "ChangeMe123!"

# ───────────── Redis ─────────────
redis_instance_type  = "cache.t3.small"
redis_engine_version = "7.0"

# ───────────── SQS ─────────────
sqs_queue_name = "primary-orders-queue"

# ───────────── Secrets Manager ─────────────
secret_name = "primary-rds-credentials"

# ───────────── DNS (optional) ─────────────
domain_name = ""
record_name = ""

# ───────────── EC2 ─────────────
ec2_instance_type = "t3.small"
ec2_key_name      = "useast"
