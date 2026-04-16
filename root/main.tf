
module "vpc" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//vpc"
  version = "0.3.6-three-tier-subnet"
  # version = "0.2.6-db-vpc-pri-sub-tag"
  # version = "0.0.6-db-vpc-pri-sub-tag"
  common_tags     = local.common_tags
  project_name    = var.project_name
  pub_sub_1a_cidr = var.pub_sub_1a_cidr
  pub_sub_2b_cidr = var.pub_sub_2b_cidr
  pub_sub_3a_cidr = var.pub_sub_3a_cidr
  pub_sub_4b_cidr = var.pub_sub_4b_cidr
  pri_sub_5a_cidr = var.pri_sub_5a_cidr
  pri_sub_6b_cidr = var.pri_sub_6b_cidr
  pri_sub_7a_cidr = var.pri_sub_7a_cidr
  pri_sub_8b_cidr = var.pri_sub_8b_cidr
  vpc_cidr        = var.vpc_cidr
}

# module "nat" {
#   source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//nat"
#   version = "0.3.6-three-tier-subnet"
#   version = "0.1.6-db-vpc-pri-sub-tag"
#   version = "0.0.6-db-vpc-pri-sub"
#   version = "0.0.1-fargate" # it has 5a and 6b subnets
#   pri_sub_3a_cidr = var.pri_sub_3a_cidr
#   pri_sub_4b_cidr = var.pri_sub_4b_cidr
#   pub_sub_1a_id   = module.vpc.pub_sub_1a_id
#   vpc_id          = module.vpc.vpc_id
# }
module "nat_instance" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//nat_instance"
  version = "0.3.6-three-tier-subnet"
  # version = "0.1.7-nat-instance-tag"
  # version = "0.0.7-nat-instance"
  pri_sub_3a_cidr  = var.pri_sub_3a_cidr
  pri_sub_4b_cidr  = var.pri_sub_4b_cidr
  vpc_cidr_block   = var.vpc_cidr
  pub_sub_1a_id    = module.vpc.pub_sub_1a_id
  vpc_id           = module.vpc.vpc_id
  ecs_node_profile = module.iam.ecs_node_profile_name
  common_tags      = local.common_tags

}


module "sg" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//sg"
  version = "0.4.6-three-tier-sg-combined" # has inbound rule for host and bridge network for testing purposes
  # version = "0.3.6-three-tier-subnet" # has inbound rule for host and bridge network for testing purposes
  # version = "0.1.3-sg-bridge-tag" # making bridge network specific change
  # version = "0.1.4-sg-host-tag" # making host network specific change
  # version = "0.0.3-bridge" # making bridge network specific change
  # version = "0.0.4-host" # making host network specific change
  backend_alb_port              = var.backend_alb_port
  backend_tg_port               = var.backend_tg_port
  backend_service_network_mode  = var.ecs_network_mode_backend
  common_tags                   = local.common_tags
  db_port                       = var.db_port
  env_suffix                    = local.env_suffix
  frontend_alb_port             = var.frontend_alb_port
  frontend_tg_port              = var.frontend_tg_port
  frontend_service_network_mode = var.ecs_network_mode_frontend
  vpc_id                        = module.vpc.vpc_id
}


module "iam" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//iam"
  version = "0.2.14-iam-env-tag"
  # version = "0.0.14-iam-env"
  # version = "0.0.7-nat-instance"
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
  version = "0.3.6-three-tier-subnet"
  # version = "0.1.21-rds-tag"
  # version = "0.0.1-fargate"
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
  version = "0.1.1-secrets-tag"
  # version = "0.0.1"
  common_tags  = local.common_tags
  db_password  = module.rds.db_password
  env_suffix   = local.env_suffix
  project_name = var.project_name
}


module "ssm" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ssm"
  version = "0.0.15-s3-ssm-deploy"
  # version = "0.0.1"
  common_tags    = local.common_tags
  db_dns_address = module.rds.db_dns_address
  env_suffix     = local.env_suffix
  project_name   = var.project_name
}

module "s3" {
  # Keep Phase 6 retention work local-path based first so lifecycle changes can be
  # exercised in this workspace before publishing a new shared module version.
  source       = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//s3"
  version      = "0.1.15-s3-lifecycle"
  # version      = "0.0.15-s3-ssm-deploy"
  common_tags                                = local.common_tags
  env_suffix                                 = local.env_suffix
  project_name                               = var.project_name
  successful_manifest_retention_days         = var.successful_manifest_retention_days
  noisy_manifest_retention_days              = var.noisy_manifest_retention_days
  noncurrent_manifest_version_retention_days = var.noncurrent_manifest_version_retention_days
}


module "cw_logs" {
  # Keep Phase 6 retention work local-path based first so log-retention changes can be
  # exercised in this workspace before publishing a new shared module version.
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//cw_logs"
  version = "0.2.1-cw-logs-lifecycle"
  # version = "0.1.1-cw-logs-tag"
  app_cluster_name            = "${var.project_name}-cluster-${local.env_suffix}"
  common_tags                 = local.common_tags
  ecr_names                   = local.ecr_names
  env_suffix                  = local.env_suffix
  project_name                = var.project_name
  app_log_retention_days      = var.app_log_retention_days
  ecs_exec_log_retention_days = var.ecs_exec_log_retention_days
}

module "ecr" {
  # Keep Phase 6 retention work local-path based first so ECR lifecycle changes can be
  # exercised in this workspace before publishing a new shared module version.
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ecr"
  version = "0.3.12-ecr-lifecycle"
  # version = "0.2.12-ecr-name-tag"
  common_tags               = local.common_tags
  ecr_names                 = local.ecr_names
  env_suffix                = local.env_suffix
  project_name              = var.project_name
  ecr_image_retention_count = var.ecr_image_retention_count
}

module "acm" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//acm"
  version = "0.2.13-acm-any-env-tag"
  # version = "0.2.13-acm-env-tag"
  # version = "0.0.1"
  domain_name = var.domain_name
  env_suffix  = local.env_suffix
}

module "route53" {
  source                = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//route53"
  version               = "0.0.10-route53-multi"
  backend_alb_dns_name  = module.lb.backend_alb_dns_name
  backend_alb_zone_id   = module.lb.backend_alb_zone_id
  domain_name           = var.domain_name
  frontend_alb_dns_name = module.lb.frontend_alb_dns_name
  frontend_alb_zone_id  = module.lb.frontend_alb_zone_id
  env_suffix            = local.env_suffix
}



# module "asg" {
#   source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//asg"
#   version = "0.4.6-three-tier-asg-placement"
#   version = "0.3.6-three-tier-subnet-asg"
#   version = "0.1.18-private-sub-asg-tag"
#   # version = "0.1.19-public-sub-asg-tag"
#   back_asg_desired_capacity  = var.back_asg_desired_capacity
#   back_asg_max_size          = var.back_asg_max_size
#   back_asg_min_size          = var.back_asg_min_size
#   back_scale_max_cap         = var.back_scale_max_cap
#   back_scale_min_cap         = var.back_scale_min_cap
#   backend_instance_type      = var.backend_instance_type
#   front_asg_desired_capacity = var.front_asg_desired_capacity
#   front_asg_max_size         = var.front_asg_max_size
#   front_asg_min_size         = var.front_asg_min_size
#   front_scale_max_cap        = var.front_scale_max_cap
#   front_scale_min_cap        = var.front_scale_min_cap
#   frontend_instance_type     = var.frontend_instance_type


#   # frontend_service_name = "frontend-service"
#   frontend_service_name = module.ecs_ec2.frontend_service_name
#   # backend_service_name = "backend-service"
#   backend_service_name    = module.ecs_ec2.backend_service_name
#   app_cluster_name        = "${var.project_name}-cluster-${local.env_suffix}"
#   ecs_node_backend_sg_id  = module.sg.ecs_node_backend_sg_id
#   ecs_node_frontend_sg_id = module.sg.ecs_node_frontend_sg_id
#   ecs_node_profile_name   = module.iam.ecs_node_profile_name
#   env_suffix              = local.env_suffix
#   pri_sub_3a_id           = module.nat_instance.pri_sub_3a_id
#   pri_sub_4b_id           = module.nat_instance.pri_sub_4b_id
#   # pri_sub_3a_id           = module.nat.pri_sub_3a_id
#   # pri_sub_4b_id           = module.nat.pri_sub_4b_id
#   pub_sub_1a_id           = module.vpc.pub_sub_1a_id
#   pub_sub_2b_id           = module.vpc.pub_sub_2b_id
#   project_name            = var.project_name
# }



module "lb" {
  # 1. Native Terraform registry path 
  source = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//lb"

  version = "0.4.6-three-tier-tg-type-combined" # also provides output for cw_alarms
  # version = "0.3.6-three-tier-sub-ec2-nonawsvpc"
  # version = "0.3.6-three-tier-subnet-ec2-awsvpc"
  # version = "0.3.6-three-tier-subnet-fargate"
  # version = "0.2.17-lb-tg-instance-private-tag"
  # version = "0.2.16-lb-tg-ip-private-subnet-tag"
  # version = "0.2.19-lb-public-subnet-tag"
  # version = "0.0.8-private-subnet"
  backend_alb_port          = var.backend_alb_port
  backend_alb_protocol      = var.backend_alb_protocol
  backend_health_check_path = var.backend_health_check_path
  backend_lb_type           = var.backend_lb_type
  backend_tg_port           = var.backend_tg_port
  backend_tg_protocol       = var.backend_tg_protocol
  # Reuse the existing tfvars-driven ECS network-mode inputs so the LB module can infer
  # instance vs ip target registration without adding yet another parallel root variable.
  backend_service_network_mode  = var.ecs_network_mode_backend
  frontend_alb_port             = var.frontend_alb_port
  frontend_alb_protocol         = var.frontend_alb_protocol
  frontend_health_check_path    = var.frontend_health_check_path
  frontend_lb_type              = var.frontend_lb_type
  frontend_service_network_mode = var.ecs_network_mode_frontend
  frontend_tg_port              = var.frontend_tg_port
  frontend_tg_protocol          = var.frontend_tg_protocol

  env_suffix                    = local.env_suffix
  app_cert_wait_certificate_arn = module.acm.app_cert_wait_certificate_arn
  backend_alb_sg_id             = module.sg.backend_alb_sg_id
  frontend_alb_sg_id            = module.sg.frontend_alb_sg_id
  pri_sub_3a_id                 = module.nat_instance.pri_sub_3a_id
  pri_sub_4b_id                 = module.nat_instance.pri_sub_4b_id
  # pri_sub_3a_id           = module.nat.pri_sub_3a_id
  # pri_sub_4b_id           = module.nat.pri_sub_4b_id
  pub_sub_1a_id = module.vpc.pub_sub_1a_id
  pub_sub_2b_id = module.vpc.pub_sub_2b_id
  vpc_id        = module.vpc.vpc_id
}



# module "ecs_ec2" {
#   source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ecs_ec2"
#   # keep probe task in fargate only because in ec2 it takes too long to stop
#   version = "0.4.6-three-tier-sub-ec2-combined" # update placement strategy and placement constraints and output for cw_alarms
#   version = "0.3.6-three-tier-sub-ec2-nonawsvpc"
#   version = "0.3.6-three-tier-subnet-ec2-awsvpc"
#   version = "0.1.20-probe-ec2-awsvpc"
#   # version = "0.1.11-probe-ec2-fargate-tag"
#   # version = "0.0.2-non-awsvpc"
#   # backend_api_name           = var.backend_api_name
#   backend_api_name           = "api-${local.env_suffix}.${var.domain_name}"
#   backend_cpu                = var.backend_cpu
#   backend_desired_count      = var.backend_desired_count
#   backend_health_check_path  = var.backend_health_check_path
#   backend_image              = var.backend_image
#   backend_memory             = var.backend_memory
#   backend_tg_port            = var.backend_tg_port
#   db_cpu                     = var.db_cpu
#   db_memory                  = var.db_memory
#   db_image                   = var.db_image
#   ecs_network_mode_db        = var.ecs_network_mode_db
#   ecs_network_mode_backend   = var.ecs_network_mode_backend
#   ecs_network_mode_frontend  = var.ecs_network_mode_frontend
#   frontend_cpu               = var.frontend_cpu
#   frontend_desired_count     = var.frontend_desired_count
#   frontend_health_check_path = var.frontend_health_check_path
#   frontend_image             = var.frontend_image
#   frontend_memory            = var.frontend_memory
#   frontend_tg_port           = var.frontend_tg_port
#   launch_type                = var.launch_type
#   project_name               = var.project_name
#   region                      = var.region
#   probe_image = var.probe_image
#   probe_cpu = var.probe_cpu
#   probe_memory = var.probe_memory
#   domain_name = "${local.env_suffix}.${var.domain_name}"


#   backend_tg_arn              = module.lb.backend_tg_arn
#   common_tags                 = local.common_tags
#   db_name                     = module.rds.db_name
#   db_port                     = module.rds.db_port
#   db_username                 = module.rds.db_username
#   ec2_provider_backend_name   = module.asg.ec2_provider_backend_name
#   ec2_provider_frontend_name  = module.asg.ec2_provider_frontend_name
#   ecs_exec_logs_name          = module.cw_logs.ecs_exec_logs_name
#   ecs_node_backend_sg_id      = module.sg.ecs_node_backend_sg_id
#   ecs_node_frontend_sg_id     = module.sg.ecs_node_frontend_sg_id
#   ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
#   ecs_task_role_arn           = module.iam.ecs_task_role_arn
#   env_suffix                  = local.env_suffix
#   frontend_tg_arn             = module.lb.frontend_tg_arn
# pri_sub_3a_id           = module.nat_instance.pri_sub_3a_id # for frontend tier
# pri_sub_4b_id           = module.nat_instance.pri_sub_4b_id
# pri_sub_5a_id           = module.nat_instance.pri_sub_5a_id # for backend tier
# pri_sub_6b_id           = module.nat_instance.pri_sub_6b_id
# # pri_sub_5a_id           = module.nat.pri_sub_5a_id
# # pri_sub_6b_id           = module.nat.pri_sub_6b_id

#   rds_db_address_arn          = module.ssm.rds_db_address_arn
#   rdsdb_root_password_arn     = module.secrets.rdsdb_root_password_arn


# }



module "cw_alarms" {
  # Keep Phase 3 telemetry work local-path based first so the monitoring contract can be
  # exercised in this workspace before you cut and publish a new reusable module version.
  # source = "../../tf-modules/ecr-three-tier-tf-modules/modules/cw_alarms"
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//cw_alarms"
  version = "0.0.22-cw-alarms"

  # Phase 3 alarms need three kinds of identifiers:
  # 1. naming/tag context from the root module
  # 2. ECS service dimensions for CPU and memory alarms
  # 3. ALB / target-group ARN suffixes for request-error and latency alarms
  common_tags                        = local.common_tags
  project_name                       = var.project_name
  env_suffix                         = local.env_suffix
  alb_5xx_threshold                  = var.alb_5xx_threshold
  frontend_latency_threshold_seconds = var.frontend_latency_threshold_seconds
  backend_latency_threshold_seconds  = var.backend_latency_threshold_seconds
  service_cpu_threshold              = var.service_cpu_threshold
  service_memory_threshold           = var.service_memory_threshold

  cluster_name          = "${var.project_name}-cluster-${local.env_suffix}"
  frontend_service_name = module.ecs_fargate.frontend_service_name
  backend_service_name  = module.ecs_fargate.backend_service_name
  # frontend_service_name = module.ecs_ec2.frontend_service_name
  # backend_service_name  = module.ecs_ec2.backend_service_name


  frontend_alb_arn_suffix = module.lb.frontend_alb_arn_suffix
  backend_alb_arn_suffix  = module.lb.backend_alb_arn_suffix
  frontend_tg_arn_suffix  = module.lb.frontend_tg_arn_suffix
  backend_tg_arn_suffix   = module.lb.backend_tg_arn_suffix

  # Use the same SNS topic as release notifications for now so runtime alarms reach the
  # same operator inbox. If alert volume grows later, this can be split into a dedicated
  # operations topic without changing individual alarm resources again.
  alarm_action_arns = [module.sns.release_notifications_topic_arn]
  ok_action_arns    = [module.sns.release_notifications_topic_arn]
}

module "sns" {
  # Phase 7 notification delivery is also kept local-path based first so the SNS contract
  # can settle in this repo before the shared module is versioned and published.
  # source = "../../tf-modules/ecr-three-tier-tf-modules/modules/sns"
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//sns"
  version = "0.0.23-sns-notifications"


  common_tags     = local.common_tags
  project_name    = var.project_name
  env_suffix      = local.env_suffix
  email_endpoints = var.notification_email_addresses
}



module "ecs_fargate" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//ecs_fargate"
  version = "0.4.6-three-tier-subnet-fargate" # update placement strategy and placement constraints and output for cw_alarms
  # version = "0.3.6-three-tier-subnet-fargate"
  # version = "0.2.11-probe-fargate-tag"
  # version = "0.0.1-fargate"
  # backend_api_name = var.backend_api_name
  backend_api_name           = "api-${local.env_suffix}.${var.domain_name}"
  backend_cpu                = var.backend_cpu
  backend_data_id            = module.efs.backend_data_id
  backend_desired_count      = var.backend_desired_count
  backend_health_check_path  = var.backend_health_check_path
  backend_image              = var.backend_image
  backend_memory             = var.backend_memory
  backend_tg_port            = var.backend_tg_port
  db_cpu                     = var.db_cpu
  db_image                   = var.db_image
  db_memory                  = var.db_memory
  frontend_cpu               = var.frontend_cpu
  frontend_desired_count     = var.frontend_desired_count
  frontend_health_check_path = var.frontend_health_check_path
  frontend_image             = var.frontend_image
  frontend_memory            = var.frontend_memory
  project_name               = var.project_name
  frontend_tg_port           = var.frontend_tg_port
  region                     = var.region

  probe_image  = var.probe_image
  probe_cpu    = var.probe_cpu
  probe_memory = var.probe_memory
  domain_name  = "${local.env_suffix}.${var.domain_name}"



  common_tags                 = local.common_tags
  backend_tg_arn              = module.lb.backend_tg_arn
  db_name                     = module.rds.db_name
  db_port                     = module.rds.db_port
  db_username                 = module.rds.db_username
  ecs_exec_logs_name          = module.cw_logs.ecs_exec_logs_name
  ecs_node_backend_sg_id      = module.sg.ecs_node_backend_sg_id
  ecs_node_frontend_sg_id     = module.sg.ecs_node_frontend_sg_id
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn
  env_suffix                  = local.env_suffix
  frontend_tg_arn             = module.lb.frontend_tg_arn
  pri_sub_3a_id               = module.nat_instance.pri_sub_3a_id # for frontend tier
  pri_sub_4b_id               = module.nat_instance.pri_sub_4b_id
  pri_sub_5a_id               = module.nat_instance.pri_sub_5a_id # for backend tier
  pri_sub_6b_id               = module.nat_instance.pri_sub_6b_id
  # pri_sub_5a_id           = module.nat.pri_sub_5a_id
  # pri_sub_6b_id           = module.nat.pri_sub_6b_id
  rds_db_address_arn      = module.ssm.rds_db_address_arn
  rdsdb_root_password_arn = module.secrets.rdsdb_root_password_arn
}

module "efs" {
  source  = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//efs"
  version = "0.3.6-three-tier-subnet-fargate"
  # version = "0.1.1-efs-fargate-tag"
  # version = "0.1.1-fargate"
  common_tags            = local.common_tags
  ecs_node_backend_sg_id = module.sg.ecs_node_backend_sg_id
  env_suffix             = local.env_suffix
  pri_sub_5a_id          = module.nat_instance.pri_sub_5a_id
  pri_sub_6b_id          = module.nat_instance.pri_sub_6b_id
  # pri_sub_5a_id           = module.nat.pri_sub_5a_id
  # pri_sub_6b_id           = module.nat.pri_sub_6b_id
  vpc_id = module.vpc.vpc_id
}
