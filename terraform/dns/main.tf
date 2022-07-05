resource "aws_route53_zone" "login_zone" {
  name = var.zone_domain
}

resource "aws_acm_certificate" "cert" {
  domain_name       = length(split(".", var.zone_domain)) > 2 ? "*.${var.zone_domain}" : var.zone_domain # Don't generate wildcards on the root domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  verification_records = [for record in aws_acm_certificate.cert.domain_validation_options : record]
}

resource "aws_route53_record" "cert_verification" {
  count = length(local.verification_records)

  depends_on = [
    aws_acm_certificate.cert,
  ]

  zone_id = aws_route53_zone.login_zone.zone_id
  name    = local.verification_records[count.index].resource_record_name
  type   = local.verification_records[count.index].resource_record_type
  records = [local.verification_records[count.index].resource_record_value]
  ttl     = 300
}
