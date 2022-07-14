variable "region" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "fqdn" {
  type = string
}

variable "fqdn_subdomain" {
  type     = string
  nullable = true
  default  = null
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}
