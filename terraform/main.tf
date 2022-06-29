# Configure the AWS Provider
provider "aws" {
  region = var.region
}

locals {
  environment = terraform.workspace
  group       = "cloud-siwe-${local.environment}"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.group}-vpc"
  cidr = "10.0.0.0/16"

  azs             = var.azs
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.2.0/24"]

  tags = {
    Environment = local.environment
    Group       = local.group
  }

  vpc_tags = {
    Name = "${local.group}-vpc"
  }

  public_subnet_tags = {
    Name = "${local.group}-public-subnet"
  }

  private_subnet_tags = {
    Name = "${local.group}-private-subnet"
  }

  igw_tags = {
    Name = "${local.group}-igw"
  }
}
