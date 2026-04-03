#---------------------------------------------
# 2. CloudWatch Log Group
#---------------------------------------------

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  # Loops through dashboard, books, and authors
  for_each = toset(var.ecr_names)
  
  # Creates distinct names like /ecs/lirwEcr-books-dev
  name              = "/ecs/${var.project_name}-${each.key}-${var.env_suffix}"
  retention_in_days = 30 
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${each.key}-logs-${var.env_suffix}"
  })
}

# 1. Create a dedicated Log Group for your terminal sessions
resource "aws_cloudwatch_log_group" "ecs_exec_logs" {
  name              = "/ecs/execute-command/${var.app_cluster_name}"
  retention_in_days = 7
   tags = merge(var.common_tags, {
    Name = "${var.project_name}-ecs-execute-command"
  })
}