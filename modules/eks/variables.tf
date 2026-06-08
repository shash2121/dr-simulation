variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "dr-sim-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS private API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "node_group_name" {
  description = "Name of the node group"
  type        = string
  default     = "default-nodes"
}

variable "node_group_instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 5
}

variable "subnet_ids" {
  description = "List of subnet IDs where the EKS cluster will be deployed"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region where the EKS cluster is deployed"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to the EKS cluster"
  type        = list(string)
  default     = []
}

# ───────────────────────────────────────
# Pod Identity
# ───────────────────────────────────────

variable "pod_sa_name" {
  description = "Kubernetes service account name for Pod Identity association (leave empty to skip)"
  type        = string
  default     = ""
}

variable "pod_sa_namespace" {
  description = "Kubernetes namespace for Pod Identity association"
  type        = string
  default     = "default"
}

variable "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret to grant access to"
  type        = string
  default     = ""
}

variable "secret_name" {
  description = "Clean secret name (without random suffix) for building wildcard ARN"
  type        = string
  default     = ""
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue to grant access to"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
