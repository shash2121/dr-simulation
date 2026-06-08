output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = module.vpc.db_subnet_group_name
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = module.rds.db_instance_arn
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.redis.redis_endpoint
}

output "redis_port" {
  description = "Redis cluster port"
  value       = module.redis.redis_port
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = module.sqs.queue_arn
}

output "secrets_manager_arn" {
  description = "Secrets Manager secret ARN"
  value       = module.secrets_manager.secret_arn
}

output "secrets_manager_name" {
  description = "Secrets Manager secret name"
  value       = module.secrets_manager.secret_name
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_oidc_issuer" {
  description = "EKS OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer
}

output "eks_node_group_role_arn" {
  description = "EKS node group IAM role ARN"
  value       = module.eks.node_group_role_arn
}

output "eks_pod_app_role_arn" {
  description = "EKS Pod Identity IAM role ARN"
  value       = module.eks.pod_app_role_arn
}

output "eks_pod_identity_association_id" {
  description = "EKS Pod Identity association ID"
  value       = module.eks.pod_identity_association_id
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID (if domain configured)"
  value       = var.domain_name != "" ? module.route53[0].hosted_zone_id : null
}

output "hosted_zone_name_servers" {
  description = "Route53 name servers (if domain configured)"
  value       = var.domain_name != "" ? module.route53[0].hosted_zone_name_servers : null
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (if domain configured)"
  value       = var.domain_name != "" ? module.acm[0].certificate_arn : null
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = module.ec2.public_ip
}

output "ec2_private_ip" {
  description = "EC2 instance private IP"
  value       = module.ec2.private_ip
}

output "ec2_public_dns" {
  description = "EC2 instance public DNS"
  value       = module.ec2.public_dns
}
