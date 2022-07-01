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

# Open Telemetry Collector

## Task Definition
resource "aws_ecs_task_definition" "otel_task_definition" {
  family = "otel"
  cpu    = 256
  memory = 512
  requires_compatibilities = [
    "FARGATE"
  ]
  network_mode = "awsvpc" # Required because of fargate
  container_definitions = jsonencode([
    {
      name      = "aws-otel-collector",
      image     = "amazon/aws-otel-collector:latest",
      essential = true,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-create-group  = "True",
          awslogs-group         = "/ecs/ecs-cwagent-ec2",
          awslogs-region        = vars.region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

## ECS Service Discovery
## GoTrue needs a way to get the IPs of the otel collector instance(s)
## We do this by integrating with Route53 Service discovery
resource "aws_service_discovery_private_dns_namespace" "otel_dns_discovery" {
  name        = "otel.${var.app_name}.discovery.local"
  description = "Service discovery for ${var.app_name}"
  vpc         = data.aws_vpc.vpc.id
}

resource "aws_service_discovery_service" "otel_service_dns_discovery_service" {
  name = "${var.app_name}_otel_dns_discovery_service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.otel_dns_discovery.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

## Service
resource "aws_ecs_service" "otel_service" {
  name            = "${var.app_name}-otel-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.otel_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets          = data.aws_subnets.private_subnets.ids
    assign_public_ip = false                                 # This is only accessible to the GoTrue instances
    security_groups  = [aws_security_group.internal_otel.id] # Setting the security group
  }

  service_registries {
    registry_arn = aws_service_discovery_service.otel_service_dns_discovery_service.arn
  }
}

# GoTrue

## Task Definition
resource "aws_ecs_task_definition" "app_task_definition" {
  family = "gotrue"
  cpu    = 2048
  memory = 4096
  requires_compatibilities = [
    "FARGATE"
  ]
  network_mode = "awsvpc" # Required because of fargate
  container_definitions = jsonencode([
    {
      name      = "gotrue",
      image     = "supabase/gotrue:latest", # TODO switch to custom image!
      essential = true,
      cpu       = 2048,
      memory    = 4096,
      portMappings = [
        {
          containerPort = 8080,
          hostPort      = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.cluster_logs.name}",
          awslogs-region        = "${var.region}",
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

## Service
resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets          = data.aws_subnets.private_subnets.ids
    assign_public_ip = false                                   # We do public ingress through the LB
    security_groups  = [aws_security_group.vpc_app_ingress.id] # Setting the security group
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our target group
    container_name   = aws_ecs_task_definition.app_task_definition.family
    container_port   = 8080 # Specifying the container port
  }
}


# Load Balencers & Networking
resource "aws_lb" "application_load_balancer" {
  name               = "${var.app_name}-load-balancer"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.public_subnets.ids
}

resource "aws_lb_target_group" "target_group" {
  name        = "${var.app_name}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.vpc.id # Referencing the default VPC
  slow_start  = 30                  # Give a 30 seccond delay to allow the service to startup
  health_check {
    protocol            = "HTTP"
    path                = "/health"
    interval            = var.health.interval
    timeout             = var.health.timeout
    healthy_threshold   = var.health.healthy_threshold
    unhealthy_threshold = var.health.unhealthy_threshold
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.application_load_balancer.arn # Referencing our load balancer
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our target group
  }
}

resource "aws_lb_listener" "listener-http" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
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
resource "aws_security_group" "internal_otel" {
  name        = "${var.app_name}-internal-otel"
  description = "Allow access to otel internally and otel to access anywhere externally"
  vpc_id      = data.aws_vpc.vpc.id
  ingress {
    from_port   = 4317 # Allowing traffic in from port 4317-4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0             # Allowing any incoming port
    to_port     = 0             # Allowing any outgoing port
    protocol    = "-1"          # Allowing any outgoing protocol
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}

resource "aws_security_group" "vpc_app_ingress" {
  name        = "${var.app_name}-vpc-ingress-to-app"
  description = "Allow app port ingress from vpc"
  vpc_id      = data.aws_vpc.vpc.id
  ingress {
    from_port   = 8080 # Allowing traffic in from port 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0             # Allowing any incoming port
    to_port     = 0             # Allowing any outgoing port
    protocol    = "-1"          # Allowing any outgoing protocol
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic out to all IP addresses
  }
}
