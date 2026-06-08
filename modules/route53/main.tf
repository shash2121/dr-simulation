data "aws_caller_identity" "current" {}

resource "aws_route53_zone" "public" {
  count = var.create_zone ? 1 : 0
  name  = var.domain_name

  tags = merge(var.tags, {
    Name        = var.domain_name
    Environment = var.environment
  })
}

resource "aws_route53_health_check" "app" {
  count             = var.create_health_check ? 1 : 0
  fqdn              = var.health_check_fqdn
  port              = var.health_check_port
  type              = "HTTP"
  resource_path     = var.health_check_path
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_request_interval

  tags = merge(var.tags, {
    Name = "${var.environment}-health-check"
  })
}

resource "aws_route53_record" "a_record" {
  count   = var.create_zone && var.create_alias ? 1 : 0
  zone_id = aws_route53_zone.public[0].zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.alias_dns_name
    zone_id                = var.alias_zone_id
    evaluate_target_health = var.evaluate_target_health
  }
}
