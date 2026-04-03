
variable "backend_alb_dns_name" {
  description = "Name for backend application load balancer dns name."
  type        = string
}

variable "backend_alb_zone_id" {
  description = "Hosted zone ID for backend application load balancer zone id."
  type        = string
}

variable "domain_name" {
  description = "Name for domain name."
  type        = string
}

variable "frontend_alb_dns_name" {
  description = "Name for frontend application load balancer dns name."
  type        = string
}

variable "frontend_alb_zone_id" {
  description = "Hosted zone ID for frontend application load balancer zone id."
  type        = string
}
