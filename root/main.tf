
module "vpc" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//vpc"
  version = "0.0.6-db-vpc-pri-sub"
  common_tags     = local.common_tags
  project_name    = var.project_name
  pub_sub_1a_cidr = var.pub_sub_1a_cidr
  pub_sub_2b_cidr = var.pub_sub_2b_cidr
  pri_sub_5a_cidr = var.pri_sub_5a_cidr
  pri_sub_6b_cidr = var.pri_sub_6b_cidr
  vpc_cidr        = var.vpc_cidr
}

# module "nat" {
#   source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//nat"
#   version = "0.0.6-db-vpc-pri-sub"
#   version = "0.0.1-fargate" # it has 5a and 6b subnets
#   pri_sub_3a_cidr = var.pri_sub_3a_cidr
#   pri_sub_4b_cidr = var.pri_sub_4b_cidr
#   pub_sub_1a_id   = module.vpc.pub_sub_1a_id
#   vpc_id          = module.vpc.vpc_id
# }
module "nat_instance" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//nat_instance"
  version = "0.0.7-nat-instance"
  pri_sub_3a_cidr = var.pri_sub_3a_cidr
  pri_sub_4b_cidr = var.pri_sub_4b_cidr
  vpc_cidr_block = var.vpc_cidr
  pub_sub_1a_id   = module.vpc.pub_sub_1a_id
  vpc_id          = module.vpc.vpc_id
  ecs_node_profile = module.iam.ecs_node_profile_name
  common_tags     = local.common_tags

}


module "sg" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//sg"
  version = "0.0.3-bridge"
  backend_alb_port  = var.backend_alb_port
  backend_tg_port   = var.backend_tg_port
  common_tags       = local.common_tags
  db_port           = var.db_port
  env_suffix        = local.env_suffix
  frontend_alb_port = var.frontend_alb_port
  frontend_tg_port  = var.frontend_tg_port
  vpc_id            = module.vpc.vpc_id
}


module "iam" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//iam"
  version = "0.0.7-nat-instance"
  account_id              = var.account_id
  region                  = var.region
  app_cluster_name        = "${var.project_name}-cluster-${local.env_suffix}"
  common_tags             = local.common_tags
  ecs_exec_logs_arn       = module.cw_logs.ecs_exec_logs_arn
  env_suffix              = local.env_suffix
  rds_db_address_arn      = module.ssm.rds_db_address_arn
  rdsdb_root_password_arn = module.secrets.rdsdb_root_password_arn
}

module "rds" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//rds"
  version = "0.0.1-fargate"
  db_engine               = var.db_engine
  db_engine_version       = var.db_engine_version
  db_instance_type        = var.db_instance_type
  db_name                 = var.db_name
  db_parameter_group_name = var.db_parameter_group_name
  db_storage              = var.db_storage
  db_storage_type         = var.db_storage_type
  db_username             = var.db_username
  project_name            = var.project_name

  common_tags        = local.common_tags
  ecs_node_rds_sg_id = module.sg.ecs_node_rds_sg_id
  env_suffix         = local.env_suffix
  pri_sub_5a_id      = module.vpc.pri_sub_5a_id
  pri_sub_6b_id      = module.vpc.pri_sub_6b_id
  vpc_id             = module.vpc.vpc_id
}



module "secrets" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//secrets"
  version = "0.0.1"
  common_tags  = local.common_tags
  db_password  = module.rds.db_password
  env_suffix   = local.env_suffix
  project_name = var.project_name
}


module "ssm" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ssm"
  version = "0.0.1"
  common_tags    = local.common_tags
  db_dns_address = module.rds.db_dns_address
  env_suffix     = local.env_suffix
  project_name   = var.project_name
}


module "cw_logs" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//cw_logs"
  version = "0.0.1"
  app_cluster_name = "${var.project_name}-cluster-${local.env_suffix}"
  common_tags      = local.common_tags
  ecr_names        = local.ecr_names
  env_suffix       = local.env_suffix
  project_name     = var.project_name
}

module "ecr" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ecr"
  version = "0.0.1"
  common_tags = local.common_tags
  ecr_names   = local.ecr_names
  env_suffix  = local.env_suffix
}

module "acm" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//acm"
  version = "0.0.1"
  domain_name = var.domain_name
}

module "route53" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//route53"
  version = "0.0.1"
  backend_alb_dns_name  = module.lb.backend_alb_dns_name
  backend_alb_zone_id   = module.lb.backend_alb_zone_id
  domain_name           = var.domain_name
  frontend_alb_dns_name = module.lb.frontend_alb_dns_name
  frontend_alb_zone_id  = module.lb.frontend_alb_zone_id
}



module "asg" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//asg"
  version = "0.0.1"
  back_asg_desired_capacity  = var.back_asg_desired_capacity
  back_asg_max_size          = var.back_asg_max_size
  back_asg_min_size          = var.back_asg_min_size
  back_scale_max_cap         = var.back_scale_max_cap
  back_scale_min_cap         = var.back_scale_min_cap
  backend_instance_type      = var.backend_instance_type
  front_asg_desired_capacity = var.front_asg_desired_capacity
  front_asg_max_size         = var.front_asg_max_size
  front_asg_min_size         = var.front_asg_min_size
  front_scale_max_cap        = var.front_scale_max_cap
  front_scale_min_cap        = var.front_scale_min_cap
  frontend_instance_type     = var.frontend_instance_type


  # frontend_service_name = "frontend-service"
  frontend_service_name = module.ecs_ec2.frontend_service_name
  # backend_service_name = "backend-service"
  backend_service_name    = module.ecs_ec2.backend_service_name
  app_cluster_name        = "${var.project_name}-cluster-${local.env_suffix}"
  ecs_node_backend_sg_id  = module.sg.ecs_node_backend_sg_id
  ecs_node_frontend_sg_id = module.sg.ecs_node_frontend_sg_id
  ecs_node_profile_name   = module.iam.ecs_node_profile_name
  env_suffix              = local.env_suffix
  pri_sub_3a_id           = module.nat_instance.pri_sub_3a_id
  pri_sub_4b_id           = module.nat_instance.pri_sub_4b_id
  # pri_sub_3a_id           = module.nat.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat.pri_sub_4b_id
  pub_sub_1a_id           = module.vpc.pub_sub_1a_id
  pub_sub_2b_id           = module.vpc.pub_sub_2b_id
  project_name            = var.project_name
}



module "lb" {
  # 1. Native Terraform registry path 
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//lb"
  version = "0.0.2-non-awsvpc"
  backend_alb_port           = var.backend_alb_port
  backend_alb_protocol       = var.backend_alb_protocol
  backend_health_check_path  = var.backend_health_check_path
  backend_lb_type            = var.backend_lb_type
  backend_tg_port            = var.backend_tg_port
  backend_tg_protocol        = var.backend_tg_protocol
  frontend_alb_port          = var.frontend_alb_port
  frontend_alb_protocol      = var.frontend_alb_protocol
  frontend_health_check_path = var.frontend_health_check_path
  frontend_lb_type           = var.frontend_lb_type
  frontend_tg_port           = var.frontend_tg_port
  frontend_tg_protocol       = var.frontend_tg_protocol

  env_suffix                    = local.env_suffix
  app_cert_wait_certificate_arn = module.acm.app_cert_wait_certificate_arn
  backend_alb_sg_id             = module.sg.backend_alb_sg_id
  frontend_alb_sg_id            = module.sg.frontend_alb_sg_id
  pri_sub_3a_id           = module.nat_instance.pri_sub_3a_id
  pri_sub_4b_id           = module.nat_instance.pri_sub_4b_id
  # pri_sub_3a_id           = module.nat.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat.pri_sub_4b_id
  pub_sub_1a_id                 = module.vpc.pub_sub_1a_id
  pub_sub_2b_id                 = module.vpc.pub_sub_2b_id
  vpc_id                        = module.vpc.vpc_id
}




module "ecs_ec2" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ecs_ec2"
  version = "0.0.2-non-awsvpc"
  backend_api_name           = var.backend_api_name
  backend_cpu                = var.backend_cpu
  backend_desired_count      = var.backend_desired_count
  backend_health_check_path  = var.backend_health_check_path
  backend_image              = var.backend_image
  backend_memory             = var.backend_memory
  backend_tg_port            = var.backend_tg_port
  db_cpu                     = var.db_cpu
  db_memory                  = var.db_memory
  db_image                   = var.db_image
  ecs_network_mode_db        = var.ecs_network_mode_db
  ecs_network_mode_frontend  = var.ecs_network_mode_frontend
  frontend_cpu               = var.frontend_cpu
  frontend_desired_count     = var.frontend_desired_count
  frontend_health_check_path = var.frontend_health_check_path
  frontend_image             = var.frontend_image
  frontend_memory            = var.frontend_memory
  frontend_tg_port           = var.frontend_tg_port
  launch_type                = var.launch_type
  project_name               = var.project_name

  backend_tg_arn              = module.lb.backend_tg_arn
  common_tags                 = local.common_tags
  db_name                     = module.rds.db_name
  db_port                     = module.rds.db_port
  db_username                 = module.rds.db_username
  ec2_provider_backend_name   = module.asg.ec2_provider_backend_name
  ec2_provider_frontend_name  = module.asg.ec2_provider_frontend_name
  ecs_exec_logs_name          = module.cw_logs.ecs_exec_logs_name
  ecs_node_backend_sg_id      = module.sg.ecs_node_backend_sg_id
  ecs_node_frontend_sg_id     = module.sg.ecs_node_frontend_sg_id
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn
  env_suffix                  = local.env_suffix
  frontend_tg_arn             = module.lb.frontend_tg_arn
  pri_sub_3a_id           = module.nat_instance.pri_sub_3a_id
  pri_sub_4b_id           = module.nat_instance.pri_sub_4b_id
  # pri_sub_3a_id           = module.nat.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat.pri_sub_4b_id
  rds_db_address_arn          = module.ssm.rds_db_address_arn
  rdsdb_root_password_arn     = module.secrets.rdsdb_root_password_arn
  region                      = var.region
}



# module "ecs_fargate" {
#   source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ecs_fargate"
#   version = "0.0.1-fargate"
#   backend_api_name = var.backend_api_name
#   backend_cpu = var.backend_cpu
#   backend_data_id = module.efs.backend_data_id
#   backend_desired_count = var.backend_desired_count
#   backend_health_check_path = var.backend_health_check_path
#   backend_image = var.backend_image
#   backend_memory = var.backend_memory
#   backend_tg_port = var.backend_tg_port
#   db_cpu = var.db_cpu
#   db_image = var.db_image
#   db_memory = var.db_memory
#   frontend_cpu = var.frontend_cpu
#   frontend_desired_count = var.frontend_desired_count
#   frontend_health_check_path = var.frontend_health_check_path
#   frontend_image = var.frontend_image
#   frontend_memory = var.frontend_memory
#   project_name = var.project_name
#   frontend_tg_port = var.frontend_tg_port
#   region = var.region


#   common_tags = local.common_tags
#   backend_tg_arn = module.lb.backend_tg_arn
#   db_name = module.rds.db_name
#   db_port = module.rds.db_port
#   db_username = module.rds.db_username
#   ecs_exec_logs_name = module.cw_logs.ecs_exec_logs_name
#   ecs_node_backend_sg_id = module.sg.ecs_node_backend_sg_id
#   ecs_node_frontend_sg_id = module.sg.ecs_node_frontend_sg_id
#   ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
#   ecs_task_role_arn = module.iam.ecs_task_role_arn
#   env_suffix = local.env_suffix
#   frontend_tg_arn = module.lb.frontend_tg_arn
  # pri_sub_3a_id           = module.nat_instance.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat_instance.pri_sub_4b_id
  # pri_sub_3a_id           = module.nat.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat.pri_sub_4b_id
#   rds_db_address_arn = module.ssm.rds_db_address_arn
#   rdsdb_root_password_arn = module.secrets.rdsdb_root_password_arn
# }

# module "efs" {
#   source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//efs"
#   version = "0.0.1-fargate"
#   common_tags = local.common_tags
#   ecs_node_backend_sg_id = module.sg.ecs_node_backend_sg_id
#   env_suffix = local.env_suffix
  # pri_sub_3a_id           = module.nat_instance.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat_instance.pri_sub_4b_id
  # pri_sub_3a_id           = module.nat.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat.pri_sub_4b_id
#   vpc_id = module.vpc.vpc_id
# }
