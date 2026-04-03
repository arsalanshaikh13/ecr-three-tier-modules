

#---------------------------------------------
#  ALB + Target Group + Listener
#---------------------------------------------

# The Internal Network Load Balancer
resource "aws_lb" "backend_alb" {
  name               = "backend-internal-alb-${var.env_suffix}"
  internal           = true
  load_balancer_type = var.backend_lb_type
  #   load_balancer_type = "application"
  enable_cross_zone_load_balancing = true

  # Deploy this in your private subnets
  subnets = [var.pri_sub_3a_id, var.pri_sub_4b_id]
  # subnets            = [var.pub_sub_1a_id, var.pub_sub_2b_id]

  # AWS recently added Security Group support for NLBs. 
  # This ensures only your App tier can talk to the database tier.
  security_groups = [var.backend_alb_sg_id]
}

# The TCP Listener
resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.backend_alb.arn
  #   port              = "80"
  port = var.backend_alb_port
  #   protocol          = "HTTP"
  protocol = var.backend_alb_protocol

  default_action {
    type = "forward"
    # This references the target group we created in the previous step
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# mongo db and internal alb terraform
# The Target Group for the Internal NLB (TCP Traffic)
resource "aws_lb_target_group" "backend_tg" {
  name = "backend-internal-tg"
  #   port     = 3200
  port = var.backend_tg_port
  #   protocol = "HTTP" # 
  protocol    = var.backend_tg_protocol
  vpc_id      = var.vpc_id
  target_type = "ip" # Must be 'ip' when using awsvpc network mode
  # target_type = "instance" # Must be 'instance' when using host/bridge network mode

  # ADD THIS LINE: Lower the wait time from 5 minutes to 30 seconds
  deregistration_delay = 30

  # Health check using TCP to ensure the port is open
  health_check {
    protocol = var.backend_tg_protocol
    # path = "/health"
    path                = var.backend_health_check_path
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }
}


resource "aws_lb" "frontend_alb" {
  name               = "frontend-public-alb-${var.env_suffix}"
  internal           = false
  load_balancer_type = var.frontend_lb_type
  #   load_balancer_type = "application"
  security_groups = [var.frontend_alb_sg_id]
  subnets         = [var.pub_sub_1a_id, var.pub_sub_2b_id]
  # subnets            = [var.pri_sub_3a_id, var.pri_sub_4b_id]
  # enable_deletion_protection = true 
}





# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Secure HTTPS Listener
resource "aws_lb_listener" "app_listener_https_secure" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = var.frontend_alb_port
  #   port              = 443
  #   protocol          = "HTTPS"
  protocol        = var.frontend_alb_protocol
  certificate_arn = var.app_cert_wait_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}
#################
# The Target Group for the External ALB (HTTP Traffic)
resource "aws_lb_target_group" "frontend_tg" {
  name = "frontend-public-tg"
  port = var.frontend_tg_port
  #   port     = 80
  #   protocol = "HTTP"
  protocol    = var.frontend_tg_protocol
  vpc_id      = var.vpc_id
  target_type = "ip" # Must be 'ip' when using awsvpc network mode
  # target_type = "instance" # Must be 'instance' when using host/bridge network mode
  # ADD THIS LINE: Lower the wait time from 5 minutes to 30 seconds
  deregistration_delay = 30

  # stickiness {
  #   type            = "lb_cookie"
  #   cookie_duration = 86400 # How long the stickiness lasts (in seconds). 86400 = 1 day.
  #   enabled         = true
  # }
  health_check {
    path                = var.frontend_health_check_path # Or a dedicated /api/health route
    protocol            = var.frontend_tg_protocol
    healthy_threshold   = 5
    unhealthy_threshold = 3
    timeout             = 15
    interval            = 30
    matcher             = "200-399"
  }
}
