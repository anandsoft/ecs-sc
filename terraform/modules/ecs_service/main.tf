variable "name" { type = string }
variable "cluster_id" { type = string }
variable "cluster_name" { type = string }
variable "cpu" { type = number }
variable "memory" { type = number }
variable "container_definitions" { type = string }
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "desired_count" { type = number }
variable "aws_region" { type = string }
variable "enable_execute_command" { type = bool }
variable "health_check_grace_period_seconds" {
  type    = number
  default = 0
}

variable "load_balancer" {
  type = object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  })
  default = null
}

variable "service_connect_namespace" { type = string }
variable "service_connect_log_group" { type = string }

variable "service_connect_server" {
  description = "Set when this service should be discovered by others. Null = client-only."
  type = object({
    port_name      = string
    discovery_name = string
    dns_name       = string
    port           = number
  })
  default = null
}

variable "tls_pca_arn" {
  type    = string
  default = null
}

variable "tls_kms_key_arn" {
  type    = string
  default = null
}

variable "tls_role_arn" {
  type    = string
  default = null
}

variable "enable_autoscaling" { type = bool }
variable "autoscaling_min" { type = number }
variable "autoscaling_max" { type = number }
variable "autoscaling_cpu_target" { type = number }

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = var.container_definitions
}

resource "aws_ecs_service" "this" {
  name                               = var.name
  cluster                            = var.cluster_id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  enable_execute_command             = var.enable_execute_command
  propagate_tags                     = "SERVICE"
  health_check_grace_period_seconds  = var.load_balancer == null ? 0 : var.health_check_grace_period_seconds
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer == null ? [] : [var.load_balancer]
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace

    dynamic "service" {
      for_each = var.service_connect_server == null ? [] : [var.service_connect_server]
      content {
        port_name      = service.value.port_name
        discovery_name = service.value.discovery_name

        client_alias {
          port     = service.value.port
          dns_name = service.value.dns_name
        }

        tls {
          role_arn = var.tls_role_arn
          kms_key  = var.tls_kms_key_arn

          issuer_cert_authority {
            aws_pca_authority_arn = var.tls_pca_arn
          }
        }
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = var.service_connect_log_group
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "sc-proxy"
      }
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "this" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max
  min_capacity       = var.autoscaling_min
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

output "service_name" { value = aws_ecs_service.this.name }
