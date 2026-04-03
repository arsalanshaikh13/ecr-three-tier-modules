#---------------------------------------------
# 3. IAM Roles (Tasks, Execution, and EC2 Nodes)
#---------------------------------------------
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution Role (For the ECS Agent on the task)
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole-${var.env_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role (For Application Code)
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecsTaskRole-${var.env_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}


# NEW: IAM Role & Profile for the underlying EC2 Instances
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
# asg instance profile iam role
resource "aws_iam_role" "ecs_node_role" {
  name               = "ecsNodeRole-${var.env_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Recommended Solution:
resource "aws_iam_role_policy_attachment" "ecs_node_role_ec2" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_node_role_exec" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs_node_role_cw" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" # Note: Corrected standard policy ARN
}
resource "aws_iam_instance_profile" "ecs_node_profile" {
  name = "ecsNodeProfile-${var.env_suffix}"
  role = aws_iam_role.ecs_node_role.name
}

# Allow Execution role to read Secrets Manager
resource "aws_iam_policy" "ecs_task_secrets_policy" {
  name = "ecsTaskSecretsPolicy-${var.env_suffix}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowReadingSecretsManager"
        Action   = ["secretsmanager:GetSecretValue",
                    "secretsmanager:PutSecretValue",
                    "secretsmanager:DescribeSecret"
                  ]
        Effect   = "Allow"
        Resource = [
                    var.rdsdb_root_password_arn
                  ]
    },
    {
        Sid      = "AllowReadingSSMParameters"
        Effect   = "Allow"
        Action   = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        # Ensure it can read your specific SSM Parameters
        Resource = [
          var.rds_db_address_arn

        ]
      }
    
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_secrets_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_secrets_policy.arn
}



# 1. The Policy that allows your Node.js app to query ECS
resource "aws_iam_policy" "ecs_metadata_policy" {
  name        = "ECSMetadataAccessPolicy"
  description = "Allows the Express app to describe tasks and container instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:DescribeContainerInstances"
        ]
        # Restrict this to your specific cluster for security
        Resource = [
          "arn:aws:ecs:${var.region}:${var.account_id}:task/${var.app_cluster_name}/*",
          "arn:aws:ecs:${var.region}:${var.account_id}:container-instance/${var.app_cluster_name}/*"
        ]
      }
    ]
  })
}

# 2. Attach it to your Task Role (Ensure your ecs_task_role exists!)
resource "aws_iam_role_policy_attachment" "ecs_metadata_attach" {
  role       = aws_iam_role.ecs_task_role.name 
  policy_arn = aws_iam_policy.ecs_metadata_policy.arn
}
resource "aws_iam_role_policy_attachment" "ecs_metadata_attach_exec" {
  # Change this to target the Execution Role, since that is what the log says your app is using!
  role       = aws_iam_role.ecs_task_execution_role.name 
  policy_arn = aws_iam_policy.ecs_metadata_policy.arn
}



# 2. Create the policy that allows the container to open a terminal
resource "aws_iam_policy" "ecs_exec_policy" {
  name = "lirw-ecs-exec-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "${var.ecs_exec_logs_arn}:*"
      }
    ]
  })
}

# 3. Attach the policy to your EXISTING Next.js Task Role
# WARNING: Make sure this is your TASK role, not your EXECUTION role!
resource "aws_iam_role_policy_attachment" "ecs_exec_attachment" {
  role       = aws_iam_role.ecs_task_role.name # Change this if your role has a different name
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}