variable "app_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "gotrue_repository_url" {
  type = string
}

variable "gotrue_image_tag" {
  type = string
}

variable "proxy_repository_url" {
  type = string
}

variable "proxy_image_tag" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "env_bucket_arn" {
  type = string
}

variable "env_file_name" {
  type = string
}

variable "region" {
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

variable "health" {
  type = map(any)

  # Default to prod setup
  default = {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 10

    deployment_minimum_healthy_percent = 100
  }
}

variable "jwt_secret_arn" {
  type = string
}

variable "database_url_arn" {
  type = string
}

variable "smtp_username_arn" {
  type = string
}

variable "smtp_password_arn" {
  type = string
}

variable "catcha_secret_arn" {
  type = string
}

variable "captcha_session_key_arn" {
  type = string
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "supabase_url" {
  type = string
}

variable "cors_origins" {
  type = string
}

variable "confirm_signup_email" {
  type = string
}

variable "reset_password_email" {
  type = string
}
