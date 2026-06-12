variable "environment_name" {
  description = "Environment name for resource naming"
  type        = string
}

variable "requester_vpc_id" {
  description = "ID of the requester VPC (primary)"
  type        = string
}

variable "accepter_vpc_id" {
  description = "ID of the accepter VPC (DR, in another region)"
  type        = string
}

variable "accepter_region" {
  description = "AWS region of the accepter VPC"
  type        = string
}

variable "requester_route_table_id" {
  description = "Private route table ID in the requester VPC"
  type        = string
}

variable "requester_public_route_table_id" {
  description = "Public route table ID in the requester VPC"
  type        = string
}

variable "accepter_route_table_id" {
  description = "Private route table ID in the accepter VPC"
  type        = string
}

variable "accepter_public_route_table_id" {
  description = "Public route table ID in the accepter VPC"
  type        = string
}

variable "accepter_cidr" {
  description = "CIDR block of the accepter VPC"
  type        = string
}

variable "requester_cidr" {
  description = "CIDR block of the requester VPC"
  type        = string
}

variable "tags" {
  description = "Tags for the peering connection"
  type        = map(string)
  default     = {}
}
