variable "redis_identifier" {
  description = "The identifier for the Redis cluster"
  type        = string
  default     = "my-redis"
}

variable "instance_type" {
  description = "The instance type for Redis"
  type        = string
  default     = "cache.t3.small"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "parameter_group_name" {
  description = "The parameter group name for Redis"
  type        = string
  default     = "default.redis7"
}

variable "port" {
  description = "The port for Redis"
  type        = number
  default     = 6379
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Redis subnet group"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where Redis will be deployed"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Redis"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = true
}
