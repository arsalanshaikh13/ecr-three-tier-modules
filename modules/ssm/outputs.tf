
output "rds_db_address_arn" {
  value = aws_ssm_parameter.rds_db_address.arn
}