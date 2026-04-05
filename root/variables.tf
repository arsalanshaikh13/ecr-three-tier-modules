##############################################
# Variables
##############################################

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, stage, prod)"
  type        = string
}

variable "db_cpu" {
  description = "CPU units for the ECS task definition"
  type        = number
  default     = 1024
}

variable "db_memory" {
  description = "Memory in MB for the ECS task definition"
  type        = number
  default     = 2048
}
variable "db_username" {
  description = "Memory in MB for the ECS task definition"
  type        = string
  default     = "admin-123"
}
variable "db_name" {
  description = "Memory in MB for the ECS task definition"
  type        = string
  # default     = "lirw-ecs"
}
# variable "db_password" {
#   description = "Memory in MB for the ECS task definition"
#   type        = string
#   sensitive = true
# }

variable "domain_name" {
  description = "The primary domain name for the application (e.g., example.com)"
  type        = string
  default     = "devsandbox.space"
}
variable "account_id" {
  description = "The primary account id"
  type        = string
  default     = "750702272407"
}

variable "back_asg_desired_capacity" {
  description = "Desired Auto Scaling Group capacity for back asg desired capacity."
  type        = number
}

variable "back_asg_max_size" {
  description = "Maximum Auto Scaling Group capacity for back asg max size."
  type        = number
}

variable "back_asg_min_size" {
  description = "Minimum Auto Scaling Group capacity for back asg min size."
  type        = number
}

variable "back_scale_max_cap" {
  description = "Maximum Auto Scaling Group capacity for back scale max cap."
  type        = number
}

variable "back_scale_min_cap" {
  description = "Minimum Auto Scaling Group capacity for back scale min cap."
  type        = number
}

variable "backend_alb_port" {
  description = "Port number for backend application load balancer port."
  type        = number
}

variable "backend_alb_protocol" {
  description = "Protocol for backend application load balancer protocol."
  type        = string
}

# variable "backend_api_name" {
#   description = "Name for backend api name."
#   type        = string
# }

variable "backend_cpu" {
  description = "CPU setting for backend cpu."
  type        = number
}



variable "backend_desired_count" {
  description = "Count value for backend desired count."
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

variable "backend_instance_type" {
  description = "EC2 instance type for backend instance type."
  type        = string
}

variable "backend_lb_type" {
  description = "Load balancer type for backend lb type."
  type        = string
}

variable "backend_memory" {
  description = "Memory setting for backend memory."
  type        = number
}

variable "backend_tg_port" {
  description = "Port number for backend target group port."
  type        = number
}

variable "backend_tg_protocol" {
  description = "Protocol for backend target group protocol."
  type        = string
}

variable "db_engine" {
  description = "Input variable for db engine."
  type        = string
}

variable "db_engine_version" {
  description = "Input variable for db engine version."
  type        = string
}

variable "db_image" {
  description = "Input variable for db image."
  type        = string
}

variable "db_instance_type" {
  description = "EC2 instance type for db instance type."
  type        = string
}

variable "db_parameter_group_name" {
  description = "Name for db parameter group name."
  type        = string
}

variable "db_port" {
  description = "Port number for db port."
  type        = number
}

variable "db_storage" {
  description = "Input variable for db storage."
  type        = string
}

variable "db_storage_type" {
  description = "Input variable for db storage type."
  type        = string
}

variable "ecs_network_mode_db" {
  description = "Input variable for ecs network mode db."
  type        = string
}

variable "ecs_network_mode_frontend" {
  description = "Input variable for ecs network mode frontend."
  type        = string
}


variable "front_asg_desired_capacity" {
  description = "Desired Auto Scaling Group capacity for front asg desired capacity."
  type        = number
}

variable "front_asg_max_size" {
  description = "Maximum Auto Scaling Group capacity for front asg max size."
  type        = number
}

variable "front_asg_min_size" {
  description = "Minimum Auto Scaling Group capacity for front asg min size."
  type        = number
}

variable "front_scale_max_cap" {
  description = "Maximum Auto Scaling Group capacity for front scale max cap."
  type        = number
}

variable "front_scale_min_cap" {
  description = "Minimum Auto Scaling Group capacity for front scale min cap."
  type        = number
}

variable "frontend_alb_port" {
  description = "Port number for frontend application load balancer port."
  type        = number
}

variable "frontend_alb_protocol" {
  description = "Protocol for frontend application load balancer protocol."
  type        = string
}

variable "frontend_cpu" {
  description = "CPU setting for frontend cpu."
  type        = number
}

variable "frontend_desired_count" {
  description = "Count value for frontend desired count."
  type        = string
}

variable "frontend_health_check_path" {
  description = "Health check path for frontend health check path."
  type        = string
}

variable "frontend_image" {
  description = "Input variable for frontend image."
  type        = string
}

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend instance type."
  type        = string
}

variable "frontend_lb_type" {
  description = "Load balancer type for frontend lb type."
  type        = string
}

variable "frontend_memory" {
  description = "Memory setting for frontend memory."
  type        = number
}


variable "frontend_tg_port" {
  description = "Port number for frontend target group port."
  type        = number
}

variable "frontend_tg_protocol" {
  description = "Protocol for frontend target group protocol."
  type        = string
}

variable "launch_type" {
  description = "Input variable for launch type."
  type        = string
}

variable "pri_sub_3a_cidr" {
  description = "CIDR block for private subnet 3 availability zone a cidr."
  type        = string
}

variable "pri_sub_4b_cidr" {
  description = "CIDR block for private subnet 4 availability zone b cidr."
  type        = string
}

variable "pri_sub_5a_cidr" {
  description = "CIDR block for private subnet 5 availability zone b cidr."
  type        = string
}
variable "pri_sub_6b_cidr" {
  description = "CIDR block for private subnet 6 availability zone a cidr."
  type        = string
}

variable "project_name" {
  description = "Name for project name."
  type        = string
}

variable "pub_sub_1a_cidr" {
  description = "CIDR block for public subnet 1 availability zone a cidr."
  type        = string
}

variable "pub_sub_2b_cidr" {
  description = "CIDR block for public subnet 2 availability zone b cidr."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for vpc cidr."
  type        = string
}

# variable "env_suffix" {
#   description = "Environment value for env suffix."
#   type        = string
# }

variable "probe_cpu" {
  description = "CPU setting for probe cpu."
  type        = number
}

variable "probe_image" {
  description = "Input variable for probe image."
  type        = string
}

variable "probe_memory" {
  description = "Memory setting for probe memory."
  type        = number
}
