variable "project_name" { type = string }
variable "force_delete" { type = bool }

locals {
  repositories = {
    ui      = "${var.project_name}/ui"
    catalog = "${var.project_name}/catalog"
    sales   = "${var.project_name}/sales"
  }
}

resource "aws_ecr_repository" "this" {
  for_each             = local.repositories
  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_urls" {
  value = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
