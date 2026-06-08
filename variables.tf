# ───────────── Region ─────────────
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# ───────────── Environment ─────────────
variable "environment" {
  description = "Environment name used for resource naming and tagging"
  type        = string
  default     = "dr-sim"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project = "DR-Simulation"
  }
}

# ───────────── VPC ─────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ───────────── Application ─────────────
variable "container_image" {
  description = "Container image for the dummy app"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:alpine"
}

variable "app_port" {
  description = "Container port for the application"
  type        = number
  default     = 80
}

variable "app_node_port" {
  description = "NodePort for the Kubernetes service"
  type        = number
  default     = 30080
}

# ───────────── EKS ─────────────
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS managed node groups"
  type        = string
  default     = "t3.micro"
}

variable "eks_min_nodes" {
  description = "Minimum nodes in EKS managed node group"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum nodes in EKS managed node group"
  type        = number
  default     = 5
}

variable "eks_desired_nodes" {
  description = "Desired nodes in EKS managed node group"
  type        = number
  default     = 2
}

variable "eks_pod_sa_name" {
  description = "Kubernetes service account name for EKS Pod Identity (leave empty to skip)"
  type        = string
  default     = "dr-sim-app-sa"
}

# ───────────── RDS ─────────────
variable "rds_engine" {
  description = "RDS engine"
  type        = string
  default     = "mysql"
}

variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "8.0"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days (0 for free tier)"
  type        = number
  default     = 0
}

variable "rds_db_name" {
  description = "Name of the database"
  type        = string
  default     = "dummydb"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "rds_password" {
  description = "Override auto-generated RDS password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

# ───────────── Redis ─────────────
variable "redis_instance_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.small"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

# ───────────── SQS ─────────────
variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
  default     = "dr-sim-queue"
}

# ───────────── Secrets Manager ─────────────
variable "secret_name" {
  description = "Name of the secret in AWS Secrets Manager"
  type        = string
  default     = "dr-sim-rds-credentials"
}

# ───────────── DNS (optional) ─────────────
variable "domain_name" {
  description = "Domain name for Route53 hosted zone (leave empty to skip DNS)"
  type        = string
  default     = ""
}

variable "record_name" {
  description = "DNS record name (e.g. 'app' for app.example.com, '' for root)"
  type        = string
  default     = ""
}

# ───────────── EC2 ─────────────
variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_name" {
  description = "SSH key pair name for EC2 instance"
  type        = string
}
