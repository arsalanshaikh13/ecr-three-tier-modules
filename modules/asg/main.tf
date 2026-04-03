#---------------------------------------------
# 6. EC2 Auto Scaling Group & Launch Template
#---------------------------------------------
# Dynamically fetch the latest Amazon Linux 2023 ECS-Optimized AMI
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

locals {
  ecs_apps = {
    frontend = {
      #   instance_type = "c7i-flex.large"
      instance_type = var.frontend_instance_type
      # subnets       = [var.pub_sub_1a_id, var.pub_sub_2b_id]
      subnets = [var.pri_sub_3a_id, var.pri_sub_4b_id]
      sg_id   = var.ecs_node_frontend_sg_id
      min     = var.front_asg_min_size
      max     = var.front_asg_max_size
      desired = var.front_asg_desired_capacity

    }
    backend = {
      instance_type = var.backend_instance_type
      subnets       = [var.pri_sub_3a_id, var.pri_sub_4b_id]
      # subnets       = [var.pub_sub_1a_id, var.pub_sub_2b_id]
      sg_id   = var.ecs_node_backend_sg_id
      min     = var.back_asg_min_size
      max     = var.back_asg_max_size
      desired = var.back_asg_desired_capacity

    }

  }
}

resource "aws_launch_template" "ecs_lt" {
  for_each = local.ecs_apps

  name_prefix   = "${var.project_name}-template-${each.key}-${var.env_suffix}"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = each.value.instance_type

  iam_instance_profile {
    name = var.ecs_node_profile_name
  }

  # This now dynamically picks the correct SG
  vpc_security_group_ids = [each.value.sg_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${var.app_cluster_name} >> /etc/ecs/ecs.config
  EOF
  )
}

resource "aws_autoscaling_group" "ecs_asg" {
  for_each = local.ecs_apps

  name                = "${var.project_name}-asg-${each.key}-${var.env_suffix}"
  vpc_zone_identifier = each.value.subnets

  #   min_size         = 1
  #   max_size         = 2
  #   desired_capacity = 1
  min_size         = each.value.min
  max_size         = each.value.max
  desired_capacity = each.value.desired

  launch_template {
    id      = aws_launch_template.ecs_lt[each.key].id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "ecs-node-${each.key}"
    propagate_at_launch = true
  }
}

#---------------------------------------------
# 12. Application Auto Scaling (Task Level) capacity provider level
#---------------------------------------------

resource "aws_ecs_capacity_provider" "ec2_provider" {
  for_each = local.ecs_apps
  name     = "ec2-capacity-provider-${each.key}-${var.env_suffix}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg[each.key].arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

# NOTE:
# Do not manage aws_ecs_cluster_capacity_providers in this ASG module.
# Keeping cluster attachment here caused destroy-order failures:
# "PutClusterCapacityProviders ... ClientException: Cluster not ACTIVE".
# Cluster attachment is intentionally managed in modules/ecs_ec2/main.tf with the cluster.



# Auto-scale tasks based on CPU Utilization

resource "aws_appautoscaling_target" "ecs_target" {
  for_each = {
    frontend = {
      min = var.front_scale_min_cap
      max = var.front_scale_max_cap
      #   min  = 2
      #   max  = 10
      name = var.frontend_service_name # Links to your frontend service
    }
    backend = {
      min  = var.back_scale_min_cap
      max  = var.back_scale_max_cap
      name = var.backend_service_name # Links to your backend service
    }
  }

  max_capacity       = each.value.max
  min_capacity       = each.value.min
  resource_id        = "service/${var.app_cluster_name}/${each.value.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  for_each = aws_appautoscaling_target.ecs_target # Automatically loops through both

  name               = "${each.key}-cpu-autoscaling-${var.env_suffix}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 75.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
