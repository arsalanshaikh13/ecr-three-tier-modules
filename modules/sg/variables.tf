variable "common_tags" {
  description = "Common tags map passed from the root module."
  type        = map(string)
}

variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where NAT resources will be created."
  type        = string
}
variable "backend_alb_port" {
  description = "Port number for backend application load balancer port."
  type        = number
}

variable "backend_tg_port" {
  description = "Port number for backend target group port."
  type        = number
}

variable "db_port" {
  description = "Port number for db port."
  type        = number
}

variable "frontend_alb_port" {
  description = "Port number for frontend application load balancer port."
  type        = number
}

variable "frontend_tg_port" {
  description = "Port number for frontend target group port."
  type        = number
}
