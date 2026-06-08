variable "domain_name" {
  description = "The domain name for the hosted zone"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "create_zone" {
  description = "Whether to create the Route53 hosted zone"
  type        = bool
  default     = true
}

variable "create_alias" {
  description = "Whether to create an alias record pointing to ALB"
  type        = bool
  default     = false
}

variable "alias_dns_name" {
  description = "ALB/NLB DNS name for the alias record"
  type        = string
  default     = ""
}

variable "alias_zone_id" {
  description = "Route53 hosted zone ID of the ALB/NLB"
  type        = string
  default     = ""
}

variable "evaluate_target_health" {
  description = "Whether to evaluate the target's health"
  type        = bool
  default     = true
}

variable "create_health_check" {
  description = "Whether to create a health check"
  type        = bool
  default     = false
}

variable "health_check_fqdn" {
  description = "FQDN for the Route53 health check"
  type        = string
  default     = ""
}

variable "health_check_port" {
  description = "Port for the health check"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path for the health check HTTP request"
  type        = string
  default     = "/"
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive failures to consider unhealthy"
  type        = number
  default     = 3
}

variable "health_check_request_interval" {
  description = "Interval in seconds between health checks"
  type        = number
  default     = 30
}

variable "record_name" {
  description = "DNS record name (e.g. 'app' or '' for root)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
