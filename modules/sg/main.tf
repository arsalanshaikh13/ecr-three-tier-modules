
#---------------------------------------------
# Security Groups
#---------------------------------------------

# security group for alb
resource "aws_security_group" "frontend_alb_sg" {
  name        = "alb security group"
  description = "enable http/https access on port 80/443"
  vpc_id      = var.vpc_id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https access"
    from_port   = var.frontend_alb_port
    to_port     = var.frontend_alb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "frontend_alb_sg"
  })
}

resource "aws_security_group" "backend_alb_sg" {
  name        = "internal alb security group"
  description = "enable http/https access on port 80/443"
  vpc_id      = var.vpc_id

  ingress {
    description     = "http access"
    from_port       = var.backend_alb_port
    to_port         = var.backend_alb_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_node_frontend_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "backend_alb_sg"
  })
}



# NEW: Node SG (For the underlying EC2 instances to talk to AWS endpoints)
resource "aws_security_group" "ecs_node_frontend_sg" {
  name        = "ecs-node-frontend-sg-${var.env_suffix}"
  description = "SG for ECS EC2 nodes frontend"
  vpc_id      = var.vpc_id

  ingress {
    description     = "node port access"
    from_port       = var.frontend_tg_port
    to_port         = var.frontend_tg_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb_sg.id]
  }

ingress {
    description     = "node port access"
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_node_backend_sg" {
  name        = "ecs-node-backend-sg-${var.env_suffix}"
  description = "SG for ECS EC2 nodes backend"
  vpc_id      = var.vpc_id

  # 2. NEW: Allow the Internal NLB to route traffic to the Mongo Container

  ingress {
    description     = "node port access"
    from_port       = var.backend_tg_port
    to_port         = var.backend_tg_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb_sg.id]
  }
  ingress {
    description     = "node port access"
    from_port   = 32768
    to_port     = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_node_rds_sg" {
  name        = "ecs-node-rds-sg-${var.env_suffix}"
  description = "SG for ECS EC2 nodes rds"
  vpc_id      = var.vpc_id

  # since i am using aws cli command to create task instead of service
  # aws will randomly assign within the ec2 instances attached to cluster
  # those ec2 instance can be from frontend or backend since i am using host network
  # the task container inherits the security group of the ec2 instance it lands on or runs on during seeding operation
  ingress {
    description     = "db port access"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_node_backend_sg.id]
  }
  # Add this block to allow Frontend nodes to reach RDS (so the seeder works anywhere)
  # ingress {
  #   description     = "Allow Frontend nodes to reach RDS for DB Seeding"
  #   from_port       = 3306
  #   to_port         = 3306
  #   protocol        = "tcp"
  #   # Replace this with your actual frontend node SG reference:
  #   security_groups = [aws_security_group.ecs_node_frontend_sg.id] 
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# resource "aws_security_group" "ecs_node_sg" {
#   name        = "ecs-node-sg-${local.env_suffix}"
#   description = "SG for ECS EC2 nodes"
#   vpc_id      = var.vpc_id

#   # 1. Existing Rule: Allow Public ALB to hit Ephemeral Ports
#   ingress {
#     description     = "node port access from ALB"
#     from_port       = 32768
#     to_port         = 65535
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }

#   # 2. NEW: Allow the Internal NLB to route traffic to the Mongo Container
#   ingress {
#     description     = "Allow traffic from Internal NLB"
#     from_port       = 27017
#     to_port         = 27017
#     protocol        = "tcp"
#     security_groups = [aws_security_group.mongodb_nlb.id]
#   }

#   # 3. NEW: The Hairpin Fix (Self-Referencing)
#   # Allows containers on the same EC2 node to talk to each other
#   ingress {
#     description = "Mongo ingress via NLB Client IP Preservation (Hairpin)"
#     from_port   = 27017
#     to_port     = 27017
#     protocol    = "tcp"
#     self        = true # This tells the SG to allow traffic from itself!
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
