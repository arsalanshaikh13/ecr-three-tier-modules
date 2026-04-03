output "frontend_alb_dns_name" {
  value = aws_lb.frontend_alb.dns_name
}
output "backend_alb_dns_name" {
  value = aws_lb.backend_alb.dns_name
}

output "frontend_alb_zone_id" {
  value = aws_lb.frontend_alb.zone_id
}
output "backend_alb_zone_id" {
  value = aws_lb.backend_alb.zone_id
}
output "backend_tg_arn" {
  value = aws_lb_target_group.backend_tg.arn
}
output "frontend_tg_arn" {
  value = aws_lb_target_group.frontend_tg.arn
}