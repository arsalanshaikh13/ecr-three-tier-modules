variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}

variable "app_cluster_name" {
  description = "Name for app cluster name."
  type        = string
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

variable "backend_instance_type" {
  description = "EC2 instance type for backend instance type."
  type        = string
}

variable "backend_service_name" {
  description = "Name for backend service name."
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

variable "ecs_node_profile_name" {
  description = "Name for ecs node profile name."
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

variable "frontend_instance_type" {
  description = "EC2 instance type for frontend instance type."
  type        = string
}

variable "frontend_service_name" {
  description = "Name for frontend service name."
  type        = string
}


variable "pri_sub_3a_id" {
  description = "ID of private subnet 3 availability zone a."
  type        = string
}

variable "pri_sub_4b_id" {
  description = "ID of private subnet 4 availability zone b."
  type        = string
}

variable "pub_sub_1a_id" {
  description = "ID of public subnet 1 availability zone a."
  type        = string
}

variable "pub_sub_2b_id" {
  description = "ID of public subnet 2 availability zone b."
  type        = string
}

variable "project_name" {
  description = "Name for project name."
  type        = string
}
