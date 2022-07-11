# GoTrue

## Task Definition
resource "aws_ecs_task_definition" "app_task_definition" {
  family = "${var.app_name}-gotrue"
  cpu    = var.cpu
  memory = var.memory
  requires_compatibilities = [
    "FARGATE"
  ]
  network_mode       = "awsvpc" # Required because of fargate
  execution_role_arn = aws_iam_role.ecsTaskExecutionRole.arn
  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-gotrue",
      image     = "${var.repository_url}:${var.image_tag}", # TODO switch to custom image!
      cpu       = var.cpu - 128,
      memory    = var.cpu - 256,
      command   = ["gotrue", "serve"],
      essential = true,
      portMappings = [
        {
          containerPort = 8080,
          hostPort      = 8080
        }
      ],
      secrets = [
        {
          name      = "DATABASE_URL",
          valueFrom = "${var.database_url_arn}"
        },
        {
          name      = "GOTRUE_JWT_SECRET",
          valueFrom = "${var.jwt_secret_arn}"
        },
        {
          name      = "GOTRUE_SMTP_USER",
          valueFrom = "${var.smtp_username_arn}"
        },
        {
          name      = "GOTRUE_SMTP_PASS",
          valueFrom = "${var.smtp_password_arn}"
        },
        {
          name      = "GOTRUE_SECURITY_CAPTCHA_SECRET",
          valueFrom = "${var.catcha_secret_arn}"
        },
        {
          name      = "GOTRUE_SESSION_KEY",
          valueFrom = "${var.captcha_session_key_arn}"
        }
      ],
      environmentFiles = [
        {
          value = "${var.env_bucket_arn}/${var.env_file_name}",
          type  = "s3"
        }
      ],
      environment = [
        {
          name  = "PORT",
          value = "8080"
        },
        {
          name  = "API_EXTERNAL_URL",
          value = "https://${var.subdomain != null ? "${var.subdomain}." : ""}${var.fqdn}"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.cluster_logs.name}",
          awslogs-region        = "${var.region}",
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name      = "aws-otel-collector",
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest",
      command   = ["--config=/etc/ecs/container-insights/otel-task-metrics-config.yaml"],
      cpu       = 128,
      memory    = 256,
      essential = true,
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
    assign_public_ip = true                                    # We do public ingress through the LB
    security_groups  = [aws_security_group.vpc_app_ingress.id] # Setting the security group
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our target group
    container_name   = aws_ecs_task_definition.app_task_definition.family
    container_port   = 8080 # Specifying the container port
  }
}

# Load Balancers & Networking
resource "aws_lb" "application_load_balancer" {
  name               = "${var.app_name}-load-balancer"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.public_subnets.ids

  security_groups = [aws_security_group.lb_ingress.id]
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

# DNS Records
resource "aws_route53_record" "dns_load_balancer" {
  zone_id = var.route53_zone_id
  name    = var.subdomain != null ? var.subdomain : "@"
  type    = "CNAME"
  records = [aws_lb.application_load_balancer.dns_name]
  ttl     = 300
}

# IAM
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${var.app_name}-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  inline_policy {
    name = "fetch-env"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:GetObject"]
          Effect   = "Allow"
          Resource = "${var.env_bucket_arn}/${var.env_file_name}"
        },
        {
          Action   = ["s3:GetBucketLocation"]
          Effect   = "Allow"
          Resource = "${var.env_bucket_arn}"
        },
      ]
    })
  }

  inline_policy {
    name = "fetch-secrets"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "secretsmanager:GetSecretValue",
            "kms:Decrypt"
          ],
          Resource = [
            "arn:aws:secretsmanager:${var.region}:*:secret:*",
            "arn:aws:kms:${var.region}:*:key/*"
          ]
        }
      ]
    })
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
