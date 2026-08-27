variable "name_prefix" { type = string }
variable "log_retention_days" { type = number }

locals {
  groups = [
    "ui",
    "catalog",
    "sales",
    "sc-ui",
    "sc-catalog",
    "sc-sales",
  ]
}

resource "aws_cloudwatch_log_group" "this" {
  for_each          = toset(local.groups)
  name              = "/ecs/${var.name_prefix}/${each.value}"
  retention_in_days = var.log_retention_days
}

output "log_group_names" {
  value = { for k, g in aws_cloudwatch_log_group.this : k => g.name }
}
