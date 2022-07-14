locals {
  app_name = "cloud-siwe"
  name     = "${local.app_name}-${terraform.workspace}"
}

module "tags" {
  source = "github.com/WalletConnect/terraform-modules/modules/tags"

  application = local.name
  env         = terraform.workspace
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

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

  enable_dns_support     = true
  enable_dns_hostnames   = true
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
}

module "secrets" {
  source = "./secrets"

  app_name = local.name
}

module "login_domain" {
  source = "./dns"

  zone_domain = var.fqdn
}

module "ecs" {
  source = "./ecs"

  vpc_name     = local.name
  app_name     = local.name
  cluster_name = local.name

  region = var.region

  acm_certificate_arn = module.login_domain.certificate_arn
  route53_zone_id     = module.login_domain.zone_id
  subdomain           = var.fqdn_subdomain
  fqdn                = var.fqdn

  env_bucket_arn = module.env_bucket.arn
  env_file_name  = "gotrue.env"

  jwt_secret_arn          = module.secrets.jwt_secret_arn
  database_url_arn        = module.secrets.database_url_arn
  smtp_username_arn       = module.secrets.smtp_username_arn
  smtp_password_arn       = module.secrets.smtp_password_arn
  catcha_secret_arn       = module.secrets.catcha_secret_arn
  captcha_session_key_arn = module.secrets.captcha_session_key_arn

  repository_url = data.aws_ecr_repository.gotrue.repository_url
  image_tag      = "0.1.5"

  cpu    = var.cpu
  memory = var.memory
}

data "aws_ecr_repository" "gotrue" {
  name = "gotrue"
}

module "env_bucket" {
  source = "github.com/WalletConnect/terraform-modules/modules/s3"

  application = local.app_name
  env = terraform.workspace
  env_group = terraform.workspace
  tags = module.tags.tags
  acl = "private"
  versioning = false
}
