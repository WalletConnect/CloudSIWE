variable "app_name" {
  type = string
}

variable "supabase_url" {
  type = string
}

variable "loadbalancer_url" {
  type = string
}

variable "subdomain" {
  type     = string
  nullable = true
}

variable "fqdn" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}
