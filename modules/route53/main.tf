#---------------------------------------------
# 8. Route 53  (HTTPS)
#---------------------------------------------
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Route 53

# 1. Root Domain (devsandbox.space)
resource "aws_route53_record" "root_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.frontend_alb_dns_name
    zone_id                = var.frontend_alb_zone_id
    evaluate_target_health = true
  }
}
# 2. Subdomains (www, books, authors)
resource "aws_route53_record" "subdomain_alias" {


  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.frontend_alb_dns_name
    zone_id                = var.frontend_alb_zone_id
    evaluate_target_health = true
  }
}
# 2. Subdomains (www, books, authors)
resource "aws_route53_record" "api_alias" {


  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.backend_alb_dns_name
    zone_id                = var.backend_alb_zone_id
    evaluate_target_health = true
  }
}
