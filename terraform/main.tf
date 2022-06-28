# Configure the AWS Provider
provider "aws" {
  region = var.region
}

module "networking" {
  source = "./networking"

  group = "cloud_siwe_${terraform.workspace}"
}
