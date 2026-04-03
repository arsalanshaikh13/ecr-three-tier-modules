#---------------------------------------------
#  ECS Cluster & Capacity Provider
#---------------------------------------------
resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_name}-cluster-${var.env_suffix}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        # Set to false unless you also create and attach an aws_kms_key
        cloud_watch_encryption_enabled = false
        cloud_watch_log_group_name     = var.ecs_exec_logs_name
      }
    }
  }
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-cluster-${var.env_suffix}"
  })
}

# NOTE:
# Keep cluster capacity-provider attachment in the same module as aws_ecs_cluster.
# This fixes destroy-order errors seen when attachment was managed in ASG:
# "deleting ECS Cluster Capacity Providers ... ClientException: Cluster not ACTIVE".
resource "aws_ecs_cluster_capacity_providers" "cluster_attach" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = [
    var.ec2_provider_frontend_name,
    var.ec2_provider_backend_name
  ]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = var.ec2_provider_backend_name
  }
}


#---------------------------------------------
# 10. ECS Task Definition
#---------------------------------------------


resource "aws_ecs_task_definition" "db_seeder" {
  family                   = "${var.project_name}-db-seeder-${var.env_suffix}"
  requires_compatibilities = ["EC2"]
  # network_mode             = "host" # Required for security group assignment
  # network_mode             = "bridge" # Required for security group assignment
  network_mode       = var.ecs_network_mode_db # Required for security group assignment
  cpu                = var.db_cpu
  memory             = var.db_memory
  execution_role_arn = var.ecs_task_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn


  container_definitions = jsonencode([
    {
      name = "${var.project_name}-db-seeder-${var.env_suffix}"
      #   image     = "alpine/mysql:seeder-latest" # Replace with your seeder image tag
      image     = var.db_image # Replace with your seeder image tag
      essential = true

      environment = [
        { name = "DB_DATABASE", value = var.db_name },
        { name = "DB_USER", value = var.db_username }
      ]

      secrets = [
        { name = "DB_PASSWORD", valueFrom = var.rdsdb_root_password_arn },
        { name = "DB_HOST", valueFrom = var.rds_db_address_arn }
      ]

      # switch to camel case for jsonencode from snake_case otherwise cloudwatch log doesn't get created
      # Changed to camelCase for AWS API compatibility
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-database-seeder-${var.env_suffix}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "seeder"
          "awslogs-create-group" : "true",

        }
      }
    }
  ])
}



resource "aws_ecs_task_definition" "backend" {
  family = "${var.project_name}-backend"
  # network_mode             = "bridge"
  # network_mode             = "host"
  network_mode             = var.ecs_network_mode_frontend
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  memory = var.backend_memory
  cpu    = var.backend_cpu


  # Provisions a var Docker volume on the EC2 host's EBS drive
  volume {
    name = "backend_data_prod"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
    }
  }
  volume {
    name = "backend_config_prod"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "local"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}_backend"
      image     = var.backend_image
      essential = true

      # Resource limits moved to the container level to prevent host OOM issues
      memory = var.backend_memory
      cpu    = var.backend_cpu

      portMappings = [
        {
          containerPort = var.backend_tg_port
          # hostPort      = 27017
          protocol = "tcp"
        }
      ]

      environment = [
        # { name = "DB_HOST", value = aws_db_instance.mysql_db.address },
        { name = "DB_DATABASE", value = var.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PORT", value = tostring(var.db_port) }
      ]

      secrets = [
        { name = "DB_PASSWORD", valueFrom = var.rdsdb_root_password_arn },
        { name = "DB_HOST", valueFrom = var.rds_db_address_arn }
      ]

      mountPoints = [
        {
          sourceVolume  = "backend_data_prod"
          containerPath = "/data/db"
          readOnly      = false
        }
      ]

      healthCheck = {
        command  = ["CMD-SHELL", "wget --no-verbose --tries=3 --spider http://127.0.0.1:${var.backend_tg_port}${var.backend_health_check_path} || exit 1"]
        interval = 10
        timeout  = 5
        retries  = 5
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-backend-${var.env_suffix}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group" : "true"
        }
      }
    }
  ])
  #   lifecycle {
  #   ignore_changes = [
  #     container_definitions,
  #     # desired_count
  #   ]
  # }

}

resource "aws_ecs_task_definition" "frontend" {
  family = "${var.project_name}-frontend"
  # network_mode             = "bridge"
  network_mode = var.ecs_network_mode_frontend
  # network_mode             = "host"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  memory = var.frontend_memory
  cpu    = var.frontend_cpu

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}_frontend"
      image     = var.frontend_image
      essential = true
      memory    = var.frontend_memory
      cpu       = var.frontend_cpu

      portMappings = [
        {
          containerPort = var.frontend_tg_port
          # hostPort      = 80
          protocol = "tcp"
        }
      ]

      environment = [
        { name = "BACKEND_ALB_URL", value = var.backend_api_name },
        { name = "VITE_API_URL", value = "/api" },

      ]

      healthCheck = {
        # curl command is missing in alpine linux
        # command     = ["CMD-SHELL", "curl -f http://varhost:3000 || exit 1"]
        # Using wget (native to Alpine), 127.0.0.1 (forces IPv4), and the new lightweight endpoint
        command     = ["CMD-SHELL", "wget --no-verbose --tries=3 --spider http://127.0.0.1:${var.frontend_tg_port}${var.frontend_health_check_path} || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 75
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-frontend-${var.env_suffix}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group" : "true"
        }
      }
    }
  ])
  # lifecycle {
  #   ignore_changes = [
  #     container_definitions,
  #   ]
  # }

}

#---------------------------------------------
# 11. ECS Service
#---------------------------------------------

resource "aws_ecs_service" "backend" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.cluster.id # Replace with your cluster ID
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  # launch_type     = "EC2"
  enable_execute_command = true

  # Attach the service to the NLB Target Group
  load_balancer {
    target_group_arn = var.backend_tg_arn
    container_name   = "${var.project_name}_backend"
    container_port   = var.backend_tg_port
    # container_port   = 3200
  }


  timeouts {
    delete = "5m"
  }

  capacity_provider_strategy {
    capacity_provider = var.ec2_provider_backend_name
    weight            = 100
    base              = 1

  }

  # this only works for awsvpc network mode not host network mode
  network_configuration {
    subnets          = [var.pri_sub_3a_id, var.pri_sub_4b_id]
    security_groups  = [var.ecs_node_backend_sg_id]
    assign_public_ip = false
    # assign_public_ip = true # it only works with fargate
  }


  health_check_grace_period_seconds = 60


  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # lifecycle {
  #   ignore_changes = [
  #     # task_definition,
  #     # desired_count
  #   ]
  # }


  # Ensure the tasks are distributed across your EC2 instances (if running multiple)
  placement_constraints {
    type = "distinctInstance"
  }

  depends_on = [aws_ecs_cluster_capacity_providers.cluster_attach]
}

# The Next.js App ECS Service
resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.cluster.id # Replace with your cluster ID
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count # Assuming you want high availability
  # launch_type     = "EC2"
  enable_execute_command = true

  # Attach the service to the ALB Target Group
  load_balancer {
    target_group_arn = var.frontend_tg_arn
    container_name   = "${var.project_name}_frontend"
    container_port   = var.frontend_tg_port
  }

  timeouts {
    delete = "5m"
  }

  capacity_provider_strategy {
    capacity_provider = var.ec2_provider_frontend_name
    weight            = 100
    base              = 1

  }

  # this only works for awsvpc network mode not host network mode
  network_configuration {
    subnets          = [var.pri_sub_3a_id, var.pri_sub_4b_id]
    security_groups  = [var.ecs_node_frontend_sg_id]
    assign_public_ip = false
    # assign_public_ip = true # it only works with fargate
  }

  health_check_grace_period_seconds = 60


  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # lifecycle {
  #   ignore_changes = [
  #     task_definition,
  #     # desired_count
  #   ]
  # }


  # Optional: Spread tasks evenly across Availability Zones
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  depends_on = [aws_ecs_cluster_capacity_providers.cluster_attach]
}
