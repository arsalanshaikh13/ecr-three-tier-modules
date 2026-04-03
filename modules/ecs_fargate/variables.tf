variable "common_tags" {
  description = "Common tags map passed from the root module."
  type        = map(string)
}

variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}

variable "backend_cpu" {
  description = "CPU setting for backend cpu."
  type        = number
}

variable "backend_data_id" {
  description = "ID of backend data."
  type        = string
}

variable "backend_desired_count" {
  description = "Count value for backend desired count."
  type        = number
}

variable "backend_api_name" {
  description = "Name for backend dns name."
  type        = string
}

variable "backend_health_check_path" {
  description = "Health check path for backend health check path."
  type        = string
}

variable "backend_image" {
  description = "Input variable for backend image."
  type        = string
}

variable "backend_memory" {
  description = "Memory setting for backend memory."
  type        = number
}

variable "backend_tg_arn" {
  description = "ARN for backend target group arn."
  type        = string
}

variable "backend_tg_port" {
  description = "Port number for backend target group port."
  type        = number
}

variable "db_cpu" {
  description = "CPU setting for db cpu."
  type        = number
}

variable "db_image" {
  description = "Input variable for db image."
  type        = string
}

variable "db_memory" {
  description = "Memory setting for db memory."
  type        = number
}

variable "db_name" {
  description = "Name for db name."
  type        = string
}

variable "db_port" {
  description = "Port number for db port."
  type        = number
}

variable "db_username" {
  description = "Input variable for db username."
  type        = string
}

variable "ecs_exec_logs_name" {
  description = "Name for ecs exec logs name."
  type        = string
}

variable "ecs_node_backend_sg_id" {
  description = "Security group ID for ecs node backend sg id."
  type        = string
}

variable "ecs_node_frontend_sg_id" {
  description = "Security group ID for ecs node frontend sg id."
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN for ecs task execution role arn."
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN for ecs task role arn."
  type        = string
}

variable "frontend_cpu" {
  description = "CPU setting for frontend cpu."
  type        = number
}

variable "frontend_desired_count" {
  description = "Count value for frontend desired count."
  type        = number
}

variable "frontend_health_check_path" {
  description = "Health check path for frontend health check path."
  type        = string
}

variable "frontend_image" {
  description = "Input variable for frontend image."
  type        = string
}

variable "frontend_memory" {
  description = "Memory setting for frontend memory."
  type        = number
}

variable "frontend_tg_arn" {
  description = "ARN for frontend target group arn."
  type        = string
}

variable "frontend_tg_port" {
  description = "Port number for frontend target group port."
  type        = number
}

variable "pri_sub_3a_id" {
  description = "ID of private subnet 3 availability zone a."
  type        = string
}

variable "pri_sub_4b_id" {
  description = "ID of private subnet 4 availability zone b."
  type        = string
}

variable "project_name" {
  description = "Name for project name."
  type        = string
}

variable "rds_db_address_arn" {
  description = "ARN for rds db address arn."
  type        = string
}

variable "rdsdb_root_password_arn" {
  description = "ARN for rdsdb root password arn."
  type        = string
}

variable "region" {
  description = "AWS region for region."
  type        = string
}
