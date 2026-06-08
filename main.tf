terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
  }

}

locals {
  name_prefix = var.environment
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Region      = var.aws_region
  })
}

data "aws_caller_identity" "current" {}

# ───────────────────────────────────────
# Auto-generated RDS password
# ───────────────────────────────────────

resource "random_password" "rds" {
  length  = 16
  special = false
}

# ───────────────────────────────────────
# VPC
# ───────────────────────────────────────

module "vpc" {
  source           = "./modules/vpc"
  aws_region       = var.aws_region
  environment_name = local.name_prefix
  vpc_cidr         = var.vpc_cidr
  cluster_name     = local.name_prefix
  tags             = local.common_tags
}

# ───────────────────────────────────────
# RDS (PostgreSQL)
# ───────────────────────────────────────

module "rds" {
  source            = "./modules/rds"
  db_identifier     = "${local.name_prefix}-rds"
  engine            = var.rds_engine
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  db_name           = var.rds_db_name
  username          = var.rds_username
  password          = var.rds_password != "" ? var.rds_password : random_password.rds.result
  port              = 3306
  backup_retention_period = var.rds_backup_retention_period
  db_subnet_group_name = module.vpc.db_subnet_group_name
  vpc_id            = module.vpc.vpc_id
  create_security_group = true
  allowed_cidr_blocks = [var.vpc_cidr]
  tags              = local.common_tags
}

# ───────────────────────────────────────
# Redis (ElastiCache)
# ───────────────────────────────────────

module "redis" {
  source            = "./modules/redis"
  redis_identifier  = "${local.name_prefix}-redis"
  instance_type     = var.redis_instance_type
  engine_version    = var.redis_engine_version
  subnet_ids        = module.vpc.private_subnet_ids
  vpc_id            = module.vpc.vpc_id
  allowed_cidr_blocks = [var.vpc_cidr]
  tags              = local.common_tags
}

# ───────────────────────────────────────
# SQS
# ───────────────────────────────────────

module "sqs" {
  source     = "./modules/sqs"
  queue_name = var.sqs_queue_name
  tags       = local.common_tags
}

# ───────────────────────────────────────
# Secrets Manager (RDS credentials)
# ───────────────────────────────────────

module "secrets_manager" {
  source                 = "./modules/secrets-manager"
  secret_name            = var.secret_name
  description            = "RDS credentials for ${local.name_prefix}"
  recovery_window_in_days = 0
  secret_string = {
    host     = split(":", module.rds.db_instance_endpoint)[0]
    port     = tostring(split(":", module.rds.db_instance_endpoint)[1])
    db_name  = var.rds_db_name
    username = var.rds_username
    password = var.rds_password != "" ? var.rds_password : random_password.rds.result
  }
  tags = local.common_tags
}

# ───────────────────────────────────────
# Security Group - EKS cluster access
# ───────────────────────────────────────

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "Additional SG to allow all traffic to EKS cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-eks-cluster-sg" })
}

# Also add ingress rule to the auto-created EKS cluster SG
resource "aws_vpc_security_group_ingress_rule" "eks_auto_allow_all" {
  security_group_id = module.eks.cluster_security_group_id
  description       = "Allow all inbound to EKS API"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  to_port           = 0
}

# ───────────────────────────────────────
# EKS
# ───────────────────────────────────────

module "eks" {
  source                     = "./modules/eks"
  cluster_name               = local.name_prefix
  cluster_version            = var.eks_cluster_version
  aws_region                 = var.aws_region
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  additional_security_group_ids = [aws_security_group.eks_cluster.id]
  node_group_instance_types  = [var.eks_node_instance_type]
  node_group_desired_size    = var.eks_desired_nodes
  node_group_min_size        = var.eks_min_nodes
  node_group_max_size        = var.eks_max_nodes
  pod_sa_name                = var.eks_pod_sa_name
  pod_sa_namespace           = "default"
  secrets_manager_arn        = module.secrets_manager.secret_arn
  secret_name                = var.secret_name
  sqs_queue_arn              = module.sqs.queue_arn
  tags                       = local.common_tags
}

# ───────────────────────────────────────
# ACM (optional)
# ───────────────────────────────────────

module "acm" {
  source   = "./modules/acm"
  count    = var.domain_name != "" ? 1 : 0
  domain_name     = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  zone_id         = module.route53[0].hosted_zone_id
  environment     = var.environment
  tags            = local.common_tags
}

# ───────────────────────────────────────
# Route53 (optional)
# ───────────────────────────────────────

module "route53" {
  source   = "./modules/route53"
  count    = var.domain_name != "" ? 1 : 0
  domain_name           = var.domain_name
  environment           = var.environment
  create_zone           = true
  create_alias          = false
  create_health_check   = false
  record_name           = var.record_name
  tags                  = local.common_tags
}

# ───────────────────────────────────────
# EC2 Instance
# ───────────────────────────────────────

module "ec2" {
  source           = "./modules/ec2"
  instance_name    = "${local.name_prefix}-ec2"
  instance_type    = var.ec2_instance_type
  key_name         = var.ec2_key_name
  subnet_id        = module.vpc.public_subnet_ids[0]
  security_group_ids = [aws_security_group.eks_cluster.id]
  tags             = local.common_tags
}
