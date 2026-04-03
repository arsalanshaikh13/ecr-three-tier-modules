output "app_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}
output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}
output "backend_service_name" {
  value = aws_ecs_service.backend.name
}