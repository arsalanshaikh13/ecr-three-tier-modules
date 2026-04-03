output "ecs_exec_logs_arn" {
    value = aws_cloudwatch_log_group.ecs_exec_logs.arn
}

output "ecs_exec_logs_name" {
  value = aws_cloudwatch_log_group.ecs_exec_logs.name
}
