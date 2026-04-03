output "rdsdb_root_password_arn" {
  value = aws_secretsmanager_secret.rdsdb_root_password.arn
}
