#---------------------------------------------
#  RDS setup
#---------------------------------------------

# We generate a random, secure password for the database via Terraform
resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = "rds-subnet-group-${var.env_suffix}"
  subnet_ids = [var.pri_sub_3a_id, var.pri_sub_4b_id]

  tags = {
    Name = "Main DB Subnet Group"
  }
}
resource "aws_db_instance" "mysql_db" {
  identifier        = "${var.project_name}-db-${var.env_suffix}"
  allocated_storage = var.db_storage
  #   allocated_storage    = 20
  #   storage_type         = "gp3"
  storage_type = var.db_storage_type
  #   engine               = "mysql"
  engine = var.db_engine
  #   engine_version       = "8.0"
  engine_version = var.db_engine_version
  #   instance_class       = "db.t3.micro" # Burstable instance for dev
  instance_class = var.db_instance_type # Burstable instance for dev

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.ecs_node_rds_sg_id]

  #   parameter_group_name = "default.mysql8.0"
  parameter_group_name = var.db_parameter_group_name
  publicly_accessible  = false
  skip_final_snapshot  = true
}


