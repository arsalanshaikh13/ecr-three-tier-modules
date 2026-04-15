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

# These CSV outputs are meant to be copied into GitHub Environment variables such as
# FRONTEND_RELEASE_ALARM_NAMES and BACKEND_RELEASE_ALARM_NAMES for Phase 3 telemetry gating.
output "frontend_release_alarm_names_csv" {
  description = "Comma-separated frontend release-health alarm names."
  value       = module.cw_alarms.frontend_release_alarm_names_csv
}

output "backend_release_alarm_names_csv" {
  description = "Comma-separated backend release-health alarm names."
  value       = module.cw_alarms.backend_release_alarm_names_csv
}

output "release_notifications_topic_arn" {
  description = "SNS topic ARN that GitHub Actions should publish release notifications to."
  value       = module.sns_notifications.release_notifications_topic_arn
}

output "release_notifications_topic_name" {
  description = "SNS topic name used for release notifications."
  value       = module.sns_notifications.release_notifications_topic_name
}

output "release_notification_email_endpoints" {
  description = "Configured email endpoints subscribed to release notifications."
  value       = module.sns_notifications.confirmed_email_endpoints
}



