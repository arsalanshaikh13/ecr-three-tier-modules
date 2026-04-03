variable "common_tags" {
  description = "Common tags map passed from the root module."
  type        = map(string)
}

variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}

variable "ecs_node_backend_sg_id" {
  description = "Input variable for ecs node backend sg."
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

variable "vpc_id" {
  description = "VPC ID for vpc id."
  type        = string
}
