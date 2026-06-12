variable "domain_name" {
  description = "The primary domain name for the ACM certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "List of alternative domain names for the certificate (e.g., ['*.example.com'])"
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Route53 hosted zone ID for DNS validation"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "wait_for_validation" {
  description = "Wait for certificate to be issued (set false to skip wait)"
  type        = bool
  default     = false
}
