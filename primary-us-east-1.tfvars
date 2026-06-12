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
cross_region_cidr_blocks = ["10.1.0.0/16"]

# ───────────── VPC Peering ─────────────
peer_vpc_id         = "vpc-0f23f00ce615cb78c"
peer_vpc_cidr       = "10.1.0.0/16"
peer_region         = "us-east-2"
peer_route_table_id        = "rtb-0eae3c7c39697fd77"
peer_public_route_table_id = "rtb-081623219c70ffbad"

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
rds_password          = "ChangeMe123!"

# ───────────── Redis ─────────────
redis_instance_type  = "cache.t3.small"
redis_engine_version = "7.0"

# ───────────── SQS ─────────────
sqs_queue_name = "primary-orders-queue"

# ───────────── Secrets Manager ─────────────
secret_name = "primary-rds-credentials"

# ───────────── DNS (optional) ─────────────
domain_name    = "infratocloud.xyz"
record_name    = ""
create_route53 = true
acm_wait_for_validation = false

# ───────────── EC2 ─────────────
ec2_instance_type = "t3.small"
ec2_key_name      = "useast"
