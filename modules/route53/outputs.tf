output "hosted_zone_id" {
  description = "The ID of the Route53 hosted zone"
  value       = var.create_zone ? aws_route53_zone.public[0].id : null
}

output "hosted_zone_name_servers" {
  description = "The name servers for the hosted zone"
  value       = var.create_zone ? aws_route53_zone.public[0].name_servers : null
}

output "hosted_zone_arn" {
  description = "The ARN of the Route53 hosted zone"
  value       = var.create_zone ? aws_route53_zone.public[0].arn : null
}

output "hosted_zone_name" {
  description = "The name of the hosted zone"
  value       = var.create_zone ? aws_route53_zone.public[0].name : null
}

output "health_check_id" {
  description = "The ID of the Route53 health check"
  value       = var.create_health_check ? aws_route53_health_check.app[0].id : null
}
