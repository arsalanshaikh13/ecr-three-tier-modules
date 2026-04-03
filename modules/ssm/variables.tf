
variable "common_tags" {
  description = "Common tags map passed from the root module."
  type        = map(string)
}

variable "env_suffix" {
  description = "Precomputed environment suffix (typically lowercase) passed from root."
  type        = string
}


variable "db_dns_address" {
  description = "Input variable for db dns address."
  type        = string
}

variable "project_name" {
  description = "Name for project name."
  type        = string
}
