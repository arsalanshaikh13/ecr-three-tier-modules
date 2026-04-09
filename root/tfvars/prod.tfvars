##############################################
# Dev Environment Variables
##############################################

region       = "us-east-2"
environment  = "prod"
project_name = "lirw-ecs"

# Networking
vpc_cidr        = "15.0.0.0/16"
pub_sub_1a_cidr = "15.0.1.0/24"
pub_sub_2b_cidr = "15.0.2.0/24"
pri_sub_3a_cidr = "15.0.3.0/24"
pri_sub_4b_cidr = "15.0.4.0/24"
pri_sub_5a_cidr = "15.0.5.0/24"
pri_sub_6b_cidr = "15.0.6.0/24"
#private_subnets = ["subnet-ccc333", "subnet-ddd444"]


## ASG settings
# asg instance type
frontend_instance_type = "c7i-flex.large"
backend_instance_type  = "c7i-flex.large"

# asg capacity
back_asg_min_size         = 2
back_asg_max_size         = 3
back_asg_desired_capacity = 2

front_asg_min_size         = 2
front_asg_max_size         = 3
front_asg_desired_capacity = 2


# auto scale ecs based on CPU utitlization
front_scale_min_cap = 2
front_scale_max_cap = 10
back_scale_min_cap  = 2
back_scale_max_cap  = 10


# lb & tg ports and protocols
backend_lb_type      = "application"
backend_alb_port     = 80
backend_alb_protocol = "HTTP"
backend_tg_port      = 3200
backend_tg_protocol  = "HTTP"

frontend_lb_type      = "application"
frontend_alb_port     = 443
frontend_alb_protocol = "HTTPS"
frontend_tg_port      = 80
frontend_tg_protocol  = "HTTP"

backend_health_check_path  = "/health"
frontend_health_check_path = "/health"


# ECS Configuration
launch_type               = "EC2"
ecs_network_mode_db       = "awsvpc"
ecs_network_mode_frontend = "awsvpc"
ecs_network_mode_backend  = "awsvpc"
# ECS task sizing
# 256 CPU units = 0.25 vCPU
# 512 MiB       = 0.5 GB
# Smallest valid Fargate size
backend_cpu            = 1024 # 0.5 vCPU
backend_memory         = 2048 # 1 GB
frontend_cpu           = 512  # 0.5 vCPU
frontend_memory        = 1024 # 1 GB

probe_cpu           = 256  # 0.5 vCPU
probe_memory        = 512 # 1 GB


frontend_desired_count = 3
backend_desired_count  = 3

frontend_image = "nginx:alpine"
backend_image  = "node:20-alpine"
probe_image = "alpine:3.20"


db_image  = "alpine/mysql:seeder-latest"
db_cpu    = 1024
db_memory = 2048
db_name   = "lirwECSDB"
# db_password = "secret_password"
db_username             = "admin123"
db_port                 = 3306
db_storage              = 20
db_storage_type         = "gp3"
db_engine               = "mysql"
db_engine_version       = "8.0"
db_instance_type        = "db.t3.micro" # Burstable instance for dev
db_parameter_group_name = "default.mysql8.0"

# domain name
domain_name      = "devsandbox.space"
# backend_api_name = "api.prod.devsandbox.space"