# Configure the AWS Provider
provider "aws" {
  region = var.region
}

module "networking" {
  source = "./networking"

  environment = terraform.workspace
  group       = "cloud_siwe_${terraform.workspace}"
}
