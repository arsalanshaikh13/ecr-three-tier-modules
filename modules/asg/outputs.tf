output "ec2_provider_backend_name" {
  value = aws_ecs_capacity_provider.ec2_provider["backend"].name
}
output "ec2_provider_frontend_name" {
  value = aws_ecs_capacity_provider.ec2_provider["frontend"].name
}