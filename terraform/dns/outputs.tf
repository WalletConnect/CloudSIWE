output "certificate_arn" {
  value = "arn:aws:acm:us-east-1:898587786287:certificate/48ee1f73-a6c9-4d53-8c22-328d1bb89bd8"
  #value = aws_acm_certificate.domain_certificate.arn
}

output "zone_arn" {
  value = ""
  #value = data.aws_route53_zone.hosted_zone.arn
}

output "zone_id" {
  value = ""
  #value = data.aws_route53_zone.hosted_zone.zone_id
}
