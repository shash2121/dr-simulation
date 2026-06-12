# ───────────── Region ─────────────
aws_region = "us-east-2"

# ───────────── Environment ─────────────
environment = "dr"
tags = {
  Project     = "DR-Simulation"
  Environment = "dr"
}

# ───────────── VPC / Networking ─────────────
vpc_cidr = "10.1.0.0/16"
cross_region_cidr_blocks = ["10.0.0.0/16"]

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
rds_instance_class    = "db.t4g.micro"
rds_allocated_storage = 20
rds_backup_retention_period = 1
rds_db_name           = "dummydb"
rds_username          = "admin"

# ───────────── Redis ─────────────
redis_instance_type  = "cache.t3.small"
redis_engine_version = "7.0"

# ───────────── SQS ─────────────
sqs_queue_name = "dr-orders-queue"

# ───────────── Secrets Manager ─────────────
secret_name = "dr-rds-credentials"

# ───────────── DNS (optional) ─────────────
domain_name    = "infratocloud.xyz"
record_name    = ""
create_route53 = false
hosted_zone_id            = "Z00120355V7T3A34VGWK"
acm_wait_for_validation   = false

# ───────────── EC2 ─────────────
ec2_instance_type = "t3.small"
ec2_key_name      = "useast2"
