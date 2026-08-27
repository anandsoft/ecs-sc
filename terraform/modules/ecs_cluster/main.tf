variable "name_prefix" { type = string }
variable "namespace" { type = string }
variable "container_insights" { type = bool }

resource "aws_service_discovery_http_namespace" "this" {
  name        = var.namespace
  description = "Service Connect namespace for ${var.name_prefix}"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.this.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

output "cluster_id" { value = aws_ecs_cluster.this.id }
output "cluster_name" { value = aws_ecs_cluster.this.name }
output "namespace_arn" { value = aws_service_discovery_http_namespace.this.arn }
output "namespace_name" { value = aws_service_discovery_http_namespace.this.name }
