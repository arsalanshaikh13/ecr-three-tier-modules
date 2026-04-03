
variable "app_cert_wait_certificate_arn" {
  description = "ARN for app cert wait certificate arn."
  type        = string
}

variable "backend_alb_port" {
  description = "Port number for backend application load balancer port."
  type        = string
}

variable "backend_alb_protocol" {
  description = "Protocol for backend application load balancer protocol."
  type        = string
}

variable "backend_health_check_path" {
  description = "Health check path for backend health check path."
  type        = string
}

variable "backend_lb_type" {
  description = "Load balancer type for backend lb type."
  type        = string
}

variable "backend_tg_port" {
  description = "Port number for backend target group port."
  type        = string
}

variable "backend_tg_protocol" {
  description = "Protocol for backend target group protocol."
  type        = string
}

variable "env_suffix" {
  description = "Environment value for env suffix."
  type        = string
}

variable "frontend_alb_port" {
  description = "Port number for frontend application load balancer port."
  type        = string
}

variable "frontend_alb_protocol" {
  description = "Protocol for frontend application load balancer protocol."
  type        = string
}

variable "frontend_alb_sg_id" {
  description = "Security group ID for frontend application load balancer sg id."
  type        = string
}

variable "frontend_health_check_path" {
  description = "Health check path for frontend health check path."
  type        = string
}

variable "frontend_lb_type" {
  description = "Load balancer type for frontend lb type."
  type        = string
}

variable "frontend_tg_port" {
  description = "Port number for frontend target group port."
  type        = string
}

variable "frontend_tg_protocol" {
  description = "Protocol for frontend target group protocol."
  type        = string
}

variable "backend_alb_sg_id" {
  description = "Security group ID for backend application load balancer sg id."
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

variable "vpc_id" {
  description = "VPC ID for vpc id."
  type        = string
}
