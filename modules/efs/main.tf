#---------------------------------------------
#  EFS file system
#---------------------------------------------
# 1. Create the persistent EFS drive
resource "aws_efs_file_system" "backend_data" {
  creation_token = "backend-fargate-data"
  encrypted      = true

  tags = {
    Name = "backend-Fargate-Storage"
  }
}

# 2. Create Mount Targets (Plugging the drive into your Private Subnets)
# You need one of these for EACH private subnet your MongoDB task might run in.
resource "aws_efs_mount_target" "backend_mount_target_1" {
  file_system_id  = aws_efs_file_system.backend_data.id
  subnet_id       = var.pri_sub_3a_id # Change to your actual subnet ID
  security_groups = [aws_security_group.efs_sg.id] # We will define this next
}

resource "aws_efs_mount_target" "backend_mount_target_2" {
  file_system_id  = aws_efs_file_system.backend_data.id
  subnet_id       = var.pri_sub_4b_id # Change to your actual subnet ID
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_security_group" "efs_sg" {
  name        = "backend-efs-sg"
  description = "Allow Fargate tasks to access EFS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow NFS traffic from MongoDB Fargate tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    # IMPORTANT: This must be the Security Group attached to your MongoDB ECS Service!
    security_groups = [var.ecs_node_backend_sg_id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
