resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "${var.app_name}-jwt-secret"
}

resource "aws_secretsmanager_secret" "database_url" {
  name = "${var.app_name}-database-url"
}

resource "aws_secretsmanager_secret" "smtp_username" {
  name = "${var.app_name}-smtp-username"
}

resource "aws_secretsmanager_secret" "smtp_password" {
  name = "${var.app_name}-smtp-password"
}

resource "aws_secretsmanager_secret" "catcha_secret" {
  name = "${var.app_name}-captcha-secret"
}
