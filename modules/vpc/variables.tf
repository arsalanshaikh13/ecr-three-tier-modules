variable "project_name" {
  description = "Name prefix used to tag and identify VPC resources for this project."
  type        = string
}

variable "common_tags" {
  description = "Common tags map passed from root and merged with resource-specific Name tags."
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "pub_sub_1a_cidr" {
  description = "CIDR block for the first public subnet in Availability Zone 1a."
  type        = string
}

variable "pub_sub_2b_cidr" {
  description = "CIDR block for the second public subnet in Availability Zone 2b."
  type        = string
}
