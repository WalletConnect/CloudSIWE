output "certificate_arn" {
  value = aws_acm_certificate.domain_certificate.arn
}

output "zone_arn" {
  value = data.aws_route53_zone.hosted_zone.arn
}

output "zone_id" {
  value = data.aws_route53_zone.hosted_zone.zone_id
}
