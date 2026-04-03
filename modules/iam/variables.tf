variable "common_tags" {
  description = "Common tags map passed from the root module."
  type        = map(string)
}

variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}
variable "rdsdb_root_password_arn" {}
variable "rds_db_address_arn" {}
variable "app_cluster_name" {}
variable "account_id" {}
variable "region" {}
variable "ecs_exec_logs_arn" {}