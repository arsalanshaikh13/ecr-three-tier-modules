# Output the endpoint so you can pass it to your seeder task
output "db_dns_address" {
  value = aws_db_instance.mysql_db.address
}
output "db_password" {
  value = aws_db_instance.mysql_db.password
  sensitive = true
}

output "db_name" {
  value = aws_db_instance.mysql_db.db_name
}
output "db_username" {
  value = aws_db_instance.mysql_db.username
}
output "db_port" {
  value = aws_db_instance.mysql_db.port
}
output "rds_db_address_arn" {
  value = aws_db_instance.mysql_db.arn
}
