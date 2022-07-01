output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt_secret.arn
}

output "database_url_arn" {
  value = aws_secretsmanager_secret.database_url.arn
}

output "smtp_username_arn" {
  value = aws_secretsmanager_secret.smtp_username.arn
}

output "smtp_password_arn" {
  value = aws_secretsmanager_secret.smtp_password.arn
}

output "catcha_secret_arn" {
  value = aws_secretsmanager_secret.catcha_secret.arn
}
