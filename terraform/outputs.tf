output "alb_url" {
  value       = "http://${module.alb.alb_dns_name}"
  description = "Public UI URL"
}

output "aws_region" {
  value = var.aws_region
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "service_connect_namespace" {
  value = module.ecs_cluster.namespace_name
}

output "catalog_endpoint" {
  value       = "http://catalog:8080"
  description = "What the UI calls. Envoy upgrades this to TLS between tasks."
}

output "sales_endpoint" {
  value = "http://sales:8080"
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "pca_arn" {
  value = module.pca.pca_arn
}
