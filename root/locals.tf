##############################################
# Locals
##############################################

locals {
  env_suffix  = lower(var.environment)

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

    ecr_names = toset(["frontend", "backend", "database-seeder"])

}

