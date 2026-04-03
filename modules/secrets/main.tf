#---------------------------------------------
# Secrets Manager setup
#---------------------------------------------

# MongoDB Root Password

resource "aws_secretsmanager_secret" "rdsdb_root_password" {
  name                    = "/${var.project_name}/${var.env_suffix}/rds-root-password"
  description             = "Root password for the rds container"
  recovery_window_in_days = 0
  tags                    = merge(var.common_tags, { Name = "${var.project_name}-rdsdb-password-secret" })


}
# Store just the password in Secrets Manager for the MongoDB container to usehttp
resource "aws_secretsmanager_secret_version" "rdsdb_root_password_val" {
  secret_id     = aws_secretsmanager_secret.rdsdb_root_password.id
  secret_string = var.db_password
  #   lifecycle {
  #   ignore_changes = [secret_string]
  # }

}
