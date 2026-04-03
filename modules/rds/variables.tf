variable "common_tags" {
  description = "Common tags map passed from the root module."
  type        = map(string)
}

variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be created."
  type        = string
}

variable "pri_sub_3a_id" {
  description = "ID of the private subnet used to db subnet group."
  type        = string
}
variable "pri_sub_4b_id" {
  description = "ID of the private subnet used to db subnet group."
  type        = string
}


variable "db_name" {
  description = "Name for db name."
  type        = string
}

variable "db_username" {
  description = "Input variable for db username."
  type        = string
}

variable "ecs_node_rds_sg_id" {
  description = "Security group ID for ecs node rds sg id."
  type        = string
}

variable "project_name" {
  description = "Name for project name."
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

variable "db_instance_type" {
  description = "EC2 instance type for db instance type."
  type        = string
}

variable "db_parameter_group_name" {
  description = "Name for db parameter group name."
  type        = string
}

variable "db_storage" {
  description = "Input variable for db storage."
  type        = string
}

variable "db_storage_type" {
  description = "Input variable for db storage type."
  type        = string
}
