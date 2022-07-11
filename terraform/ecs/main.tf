# Log Group for our App
resource "aws_cloudwatch_log_group" "cluster_logs" {
  name              = "${var.cluster_name}_logs"
  retention_in_days = 14
}

# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = var.cluster_name

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = false
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.cluster_logs.name
      }
    }
  }
}

## VPC Reference
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

## Providing a reference to our default subnets
data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  filter {
    name   = "tag:Visibility"
    values = ["private"]
  }
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  filter {
    name   = "tag:Visibility"
    values = ["public"]
  }
}

# Security Groups
resource "aws_security_group" "vpc_app_ingress" {
  name        = "${var.app_name}-vpc-ingress-to-app"
  description = "Allow app port ingress from vpc"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block] # Allowing traffic in from VPC
  }

  egress {
    from_port   = 0             # Allowing any incoming port
    to_port     = 0             # Allowing any outgoing port
    protocol    = "-1"          # Allowing any outgoing protocol
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "lb_ingress" {
  name        = "${var.app_name}-lb-ingress"
  description = "Allow app port ingress from vpc"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0                             # Allowing any incoming port
    to_port     = 0                             # Allowing any outgoing port
    protocol    = "-1"                          # Allowing any outgoing protocol
    cidr_blocks = [data.aws_vpc.vpc.cidr_block] # Allowing traffic out to all VPC IP addresses
  }

  lifecycle {
    create_before_destroy = true
  }
}
