output "certificate_arn" {
  value = aws_acm_certificate.cert.arn
}

output "zone_arn" {
  value = aws_route53_zone.login_zone.arn
}

output "zone_id" {
  value = aws_route53_zone.login_zone.zone_id
}
