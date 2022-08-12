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
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-gotrue",
      image     = "${var.gotrue_repository_url}:${var.gotrue_image_tag}", # TODO switch to custom image!
      cpu       = var.cpu - 128,                                          # Remove sidecar memory/cpu so rest is assigned to GoTrue
      memory    = var.cpu - 128,
      command   = ["gotrue", "serve"],
      essential = true,
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
          value = "https://${var.subdomain != null ? "${var.subdomain}." : ""}${var.fqdn}/auth/v1"
        },
        {
          name  = "GOTRUE_MAILER_SUBJECTS_RECOVERY",
          value = "Reset Your WalletConnect Password"
        },
        {
          name  = "GOTRUE_MAILER_TEMPLATES_RECOVERY",
          value = var.reset_password_email
        },
        {
          name  = "GOTRUE_MAILER_SUBJECTS_CONFIRMATION",
          value = "Confirm Your WalletConnect Signup"
        },
        {
          name  = "GOTRUE_MAILER_TEMPLATES_CONFIRMATION",
          value = var.confirm_signup_email
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
      name      = "nginx-proxy",
      image     = "${var.proxy_repository_url}:${var.proxy_image_tag}",
      cpu       = 128,
      memory    = 128,
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80
        }
      ],
      environment = [
        {
          name  = "DOMAIN",
          value = "https://${var.subdomain != null ? "${var.subdomain}." : ""}${var.fqdn}"
        },
        {
          name  = "SUPABASE_URL",
          value = var.supabase_url
        },
        {
          name  = "GOTRUE_CONTAINER_IP",
          value = "localhost"
        },
        {
          name  = "GOTRUE_CONTAINER_PORT",
          value = "8080"
        },
        {
          name  = "CORS_ORIGINS",
          value = var.cors_origins
        },
        {
          name  = "CORS_METHODS",
          value = "GET, POST, PATCH, OPTIONS"
        },
        {
          name  = "CORS_HEADERS",
          value = "*"
        }
      ]
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
    subnets          = var.private_subnets
    assign_public_ip = true                                # We do public ingress through the LB
    security_groups  = [aws_security_group.app_ingress.id] # Setting the security group
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our target group
    container_name   = "nginx-proxy"
    container_port   = 80 # Specifying the container port
  }
}

# Load Balancers & Networking
resource "aws_lb" "application_load_balancer" {
  name               = "${var.app_name}-load-balancer"
  load_balancer_type = "application"
  subnets            = var.public_subnets

  security_groups = [aws_security_group.lb_ingress.id]
}

resource "aws_lb_target_group" "target_group" {
  name        = "${var.app_name}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id # Referencing the default VPC
  slow_start  = 30         # Give a 30 seccond delay to allow the service to startup
  health_check {
    protocol            = "HTTP"
    path                = "/auth/v1/health" # GoTrue's health path
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
  name    = var.subdomain != null ? var.subdomain : var.fqdn
  type    = "A"

  alias {
    name                   = aws_lb.application_load_balancer.dns_name
    zone_id                = aws_lb.application_load_balancer.zone_id
    evaluate_target_health = true
  }
}

# IAM
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.app_name}-ecs-task-execution-role"
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_cloudwatch_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_xray_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Security Groups
resource "aws_security_group" "app_ingress" {
  name        = "${var.app_name}-ingress-to-app"
  description = "Allow app port ingress"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_ingress.id]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
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
  vpc_id      = var.vpc_id

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
    from_port   = 0              # Allowing any incoming port
    to_port     = 0              # Allowing any outgoing port
    protocol    = "-1"           # Allowing any outgoing protocol
    cidr_blocks = [var.vpc_cidr] # Allowing traffic out to all VPC IP addresses
  }

  lifecycle {
    create_before_destroy = true
  }
}
