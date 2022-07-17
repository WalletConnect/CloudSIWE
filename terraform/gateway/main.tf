# API Gateway
resource "aws_apigatewayv2_api" "gateway" {
  name          = "${var.app_name}-gateway"
  protocol_type = "HTTP"

  disable_execute_api_endpoint = true

  cors_configuration {
    allow_credentials = false
    allow_origins = ["*"] # TODO make more specific using env
    allow_methods = ["HEAD", "POST"]
  }
}

# Integrations
resource "aws_apigatewayv2_integration" "supabase_passthrough" {
  api_id           = aws_apigatewayv2_api.gateway.id
  integration_type = "HTTP_PROXY"

  integration_method = "ANY"
  integration_uri    = "${var.supabase_url}/{proxy}"
}

resource "aws_apigatewayv2_integration" "gotrue" {
  api_id           = aws_apigatewayv2_api.gateway.id
  integration_type = "HTTP_PROXY"

  integration_method = "ANY"
  integration_uri    = "http://${var.loadbalancer_url}/{proxy}"
}

# Routes
resource "aws_apigatewayv2_route" "auth_override" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "ANY /auth/v1/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.gotrue.id}"
}

resource "aws_apigatewayv2_route" "passthrough" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.supabase_passthrough.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.gateway.id
  name   = "default"

  auto_deploy = true
}

locals {
  domain = var.subdomain != null ? "${var.subdomain}.${var.fqdn}" : var.fqdn
}

resource "aws_apigatewayv2_domain_name" "login" {
  domain_name = local.domain

  domain_name_configuration {
    certificate_arn = var.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# DNS Records
resource "aws_route53_record" "gateway_record" {
  zone_id = var.route53_zone_id
  name    = aws_apigatewayv2_domain_name.login.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.login.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.login.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# Mapping
resource "aws_apigatewayv2_api_mapping" "default_mapping" {
  api_id      = aws_apigatewayv2_api.gateway.id
  domain_name = aws_apigatewayv2_domain_name.login.id
  stage       = aws_apigatewayv2_stage.default.id
}
