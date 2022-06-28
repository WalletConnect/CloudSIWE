# Configure the AWS Provider
provider "aws" {
  region = var.region
}

locals {
  environment = terraform.workspace
  group       = "cloud_siwe_${terraform.workspace}"
}

resource "aws_vpc" "cloud_siwe_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "cloud_siwe_${locals.environment}_vpc"
    Environment = locals.environment # To make filtering easier
    Group       = locals.group # To make filtering easier
  }
}

resource "aws_subnet" "cloud_siwe_private_subnet" {
  vpc_id                  = aws_vpc.cloud_siwe_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name        = "cloud_siwe_${locals.environment}_private_subnet"
    Environment = locals.environment # To make filtering easier
    Group       = locals.group # To make filtering easier
  }
}

resource "aws_subnet" "cloud_siwe_public_subnet" {
  vpc_id     = aws_vpc.cloud_siwe_vpc.id
  cidr_block = "10.0.2.0/24"
  
  tags = {
    Name        = "cloud_siwe_${locals.environment}_public_subnet"
    Environment = locals.environment # To make filtering easier
    Group       = locals.group # To make filtering easier
  }
}
