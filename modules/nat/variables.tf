variable "pri_sub_3a_cidr" {
  description = "CIDR block for the first private subnet in Availability Zone 3a."
  type        = string
}

variable "pri_sub_4b_cidr" {
  description = "CIDR block for the second private subnet in Availability Zone 4b."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where NAT resources will be created."
  type        = string
}

variable "pub_sub_1a_id" {
  description = "ID of the public subnet used to host the NAT gateway."
  type        = string
}
# variable "pri_sub_5a_cidr" {}
# variable "pri_sub_6b_cidr" {}
# variable "pri_sub_7a_cidr" {}
# variable "pri_sub_8b_cidr" {}
