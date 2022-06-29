# Configure the AWS Provider
provider "aws" {
  region = var.region
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
  private_subnets = terraform.workspace == "dev" ? ["10.0.1.0/24"] : ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = terraform.workspace == "dev" ? ["10.0.4.0/24"] : ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  tags     = module.base_tags.tags.value
  vpc_tags = module.base_tags.tags.value
  igw_tags = module.base_tags.tags.value

  private_subnet_tags = merge(
    {
      Purpose = "service"
    },
    module.base_tags.tags.value
  )

  public_subnet_tags = merge(
    {
      Purpose = "app"
    },
    module.base_tags.tags.value
  )
}
