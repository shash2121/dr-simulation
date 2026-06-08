output "certificate_arn" {
  description = "The ARN of the validated ACM certificate"
  value       = aws_acm_certificate_validation.cert.certificate_arn
}

output "certificate_domain" {
  description = "The domain name of the certificate"
  value       = aws_acm_certificate.cert.domain_name
}
