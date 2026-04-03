output "ecs_node_rds_sg_id" {
  value = aws_security_group.ecs_node_rds_sg.id
}
output "ecs_node_backend_sg_id" {
  value = aws_security_group.ecs_node_backend_sg.id
}
output "ecs_node_frontend_sg_id" {
  value = aws_security_group.ecs_node_frontend_sg.id
}
output "frontend_alb_sg_id" {
  value = aws_security_group.frontend_alb_sg.id
}
output "backend_alb_sg_id" {
  value = aws_security_group.backend_alb_sg.id
}