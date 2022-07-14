data "aws_route53_zone" "hosted_zone" {
  name = var.zone_domain
}

resource "aws_acm_certificate" "domain_certificate" {
  domain_name       = var.cert_subdomain != null ? "${var.cert_subdomain}.${var.zone_domain}" : var.zone_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  verification_records = [for record in aws_acm_certificate.domain_certificate.domain_validation_options : record]
}

resource "aws_route53_record" "cert_verification" {
  count = length(local.verification_records)

  depends_on = [
    aws_acm_certificate.domain_certificate,
  ]

  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = local.verification_records[count.index].resource_record_name
  type    = local.verification_records[count.index].resource_record_type
  records = [local.verification_records[count.index].resource_record_value]
  ttl     = 300

  allow_overwrite = true # Removes error when record already exists
}
