#---------------------------------------------
# 1. ECR Repository (Immutable + Lifecycle)
#---------------------------------------------
# vars {
#   ecr_names = toset(["frontend", "backend", "database-seeder"])
# }

resource "aws_ecr_repository" "app_repos" {
  for_each             = toset(var.ecr_names)
  name                 = "lirw-ecr-${each.key}-repo-${var.env_suffix}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name = "ecr-lirwEcr-${each.key}-repo-${var.env_suffix}"
  })
}


resource "aws_ecr_lifecycle_policy" "app_repo_lifecycle" {
  for_each = var.ecr_names

  # repository = each.value.name # References the name from the repo loop above
  repository = aws_ecr_repository.app_repos[each.key].name # References the name from the repo loop above

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = { type = "expire" }
    }]
  })
}
