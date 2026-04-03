variable "common_tags" {
  description = "Common tags map passed from the root module."
  type        = map(string)
}
variable "ecr_names" {
  description = "ecr names to be used for function for_each."
  type        = set(string)
}

variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}

variable "app_cluster_name" {
  description = "Name for app cluster name."
  type        = string
}

variable "project_name" {
  description = "Name for project name."
  type        = string
}
