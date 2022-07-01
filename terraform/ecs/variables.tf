variable "app_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_name" {
    type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "region" {
    type = string
}

variable "health" {
  type = map(any)

  # Default to prod setup
  default = {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 15

    deployment_minimum_healthy_percent = 100
  }
}
