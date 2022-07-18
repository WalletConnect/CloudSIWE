# API Gateway
resource "aws_api_gateway_rest_api" "gateway" {
  name = "${var.app_name}-gateway"

  disable_execute_api_endpoint = true

  endpoint_configuration {
    types = ["EDGE"]
  }
}

# cors_configuration {
#   allow_credentials = false
#   allow_origins     = ["https://*", "http://localhost"] # TODO make more specific using env
#   allow_methods     = ["GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS"]
# }

resource "aws_api_gateway_resource" "supabase_passthrough_resource" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_rest_api.gateway.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "supabase_passthrough_method" {
  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  resource_id   = aws_api_gateway_resource.supabase_passthrough_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "supabase_passthrough" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = aws_api_gateway_resource.supabase_passthrough_resource.id
  http_method = aws_api_gateway_method.supabase_passthrough_method.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${var.supabase_url}/{proxy}"
}

resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_rest_api.gateway.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "auth_v1_resource" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_resource.auth_resource.id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "gotrue_resource" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_resource.auth_v1_resource.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "gotrue_method" {
  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  resource_id   = aws_api_gateway_resource.gotrue_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "gotrue" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  resource_id = aws_api_gateway_resource.gotrue_resource.id
  http_method = aws_api_gateway_method.gotrue_method.http_method

  type                    = "AWS"
  integration_http_method = "ANY"
  uri                     = "http://${var.loadbalancer_url}/{proxy}"
}

# Routes
# TODO convert to REST API
# resource "aws_apigatewayv2_route" "auth_override" {
#   api_id    = aws_apigatewayv2_api.gateway.id
#   route_key = "ANY /auth/v1/{proxy+}"

#   target = "integrations/${aws_apigatewayv2_integration.gotrue.id}"
# }

# resource "aws_apigatewayv2_route" "passthrough" {
#   api_id    = aws_apigatewayv2_api.gateway.id
#   route_key = "ANY /{proxy+}"

#   target = "integrations/${aws_apigatewayv2_integration.supabase_passthrough.id}"
# }

# Deployments
resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id

  triggers = {
    redeployment = sha1(join(",", tolist([
      jsonencode(aws_api_gateway_rest_api.gateway),
      # Supabase Passthrough
      jsonencode(aws_api_gateway_integration.supabase_passthrough),
      # Auth Pasthrough/Override
      # jsonencode(aws_api_gateway_integration.gotrue),
    ])))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stages
resource "aws_api_gateway_stage" "default" {
  stage_name = "default"

  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  deployment_id = aws_api_gateway_deployment.default.id
}

locals {
  domain = var.subdomain != null ? "${var.subdomain}.${var.fqdn}" : var.fqdn
}

resource "aws_api_gateway_domain_name" "login" {
  domain_name     = local.domain
  certificate_arn = var.acm_certificate_arn
  security_policy = "TLS_1_2"
}

# DNS Records
resource "aws_route53_record" "gateway_record" {
  zone_id = var.route53_zone_id
  name    = aws_api_gateway_domain_name.login.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.login.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.login.cloudfront_zone_id
    evaluate_target_health = true
  }
}

# Mapping
resource "aws_api_gateway_base_path_mapping" "default_mapping" {
  api_id      = aws_api_gateway_rest_api.gateway.id
  domain_name = aws_api_gateway_domain_name.login.domain_name
  stage_name  = aws_api_gateway_stage.default.stage_name
}
