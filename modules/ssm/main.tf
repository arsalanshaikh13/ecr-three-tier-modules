#---------------------------------------------
# SSM Parameter setup
#---------------------------------------------


resource "aws_ssm_parameter" "rds_db_address" {
  name        = "/${var.project_name}/${var.env_suffix}/rds_db_address"
  description = "database dns address"
  type        = "SecureString"
  value       = var.db_dns_address

  # lifecycle {
  #   ignore_changes = [value]
  # }
}

