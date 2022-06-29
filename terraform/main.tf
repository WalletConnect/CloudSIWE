# Configure the AWS Provider
provider "aws" {
  region = var.region

  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

locals {
  group = "cloud-siwe-${terraform.workspace}"
}

module "base_tags" {
  source = "WalletConnect/terraform-modules/tags"

  application = local.group
  env         = terraform.workspace
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.group}-vpc"
  cidr = "10.0.0.0/16"

  azs             = var.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  tags = module.base_tags.tags.value
  private_subnet_tags = {
    Visibility = "private"
  }
  public_subnet_tags = {
    Visibility = "public"
  }
}
