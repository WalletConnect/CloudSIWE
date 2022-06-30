locals {
  group = "cloud-siwe-${terraform.workspace}"
}

module "tags" {
  source = "github.com/WalletConnect/terraform-modules/modules/tags"

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

  tags = module.tags.tags
  private_subnet_tags = {
    Visibility = "private"
  }
  public_subnet_tags = {
    Visibility = "public"
  }
}

# TODO Limit to Prod only

resource "aws_ecrpublic_repository" "gotrue" {
  provider        = aws.us_east_1 # Only avaliable here
  repository_name = "gotrue"

  catalog_data {
    architectures = [
      "x86",
    ]
    operating_systems = [
      "Linux",
    ]
  }
}

# TODO Limit to Prod only
resource "aws_ecr_repository" "gotrue" {
  name                 = "gotrue"
  image_tag_mutability = "MUTABLE"
}
