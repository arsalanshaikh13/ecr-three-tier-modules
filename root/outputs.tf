##############################################
# Outputs
##############################################

# output "ecr_repository_url" {
#   description = "ECR Repository URL"
#   value       = aws_ecr_repository.app_repo.repository_url
# }

# output "ecs_cluster_name" {
#   description = "ECS Cluster name"
#   value       = module.ecs_ec2.app_cluster_name
# }
# output "ecs_cluster_name" {
#   description = "ECS Cluster name"
#   value       = module.ecs_fargate.app_cluster_name
# }

output "frontend_alb_dns_name" {
  description = "ALB DNS name"
  value       = module.lb.frontend_alb_dns_name
}



