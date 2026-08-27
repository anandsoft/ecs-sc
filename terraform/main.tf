data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  is_prod     = var.environment == "prod"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  catalog_dns  = "catalog"
  sales_dns    = "sales"
  backend_port = 8080

  log = module.observability.log_group_names
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]
  private_subnet_cidrs = [cidrsubnet(var.vpc_cidr, 8, 11), cidrsubnet(var.vpc_cidr, 8, 12)]
  enable_nat_gateway   = var.enable_nat_gateway
  nat_gateway_ha       = var.nat_gateway_ha
}

module "security_groups" {
  source = "./modules/security_groups"

  name_prefix  = local.name_prefix
  vpc_id       = module.vpc.vpc_id
  backend_port = local.backend_port
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  force_delete = !local.is_prod
}

module "iam" {
  source      = "./modules/iam"
  name_prefix = local.name_prefix
}

module "pca" {
  source       = "./modules/pca"
  name_prefix  = local.name_prefix
  tls_role_arn = module.iam.service_connect_tls_role_arn
}

module "alb" {
  source = "./modules/alb"

  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  acm_certificate_arn   = var.acm_certificate_arn
}

module "ecs_cluster" {
  source = "./modules/ecs_cluster"

  name_prefix        = local.name_prefix
  namespace          = "${var.project_name}.local"
  container_insights = var.container_insights
}

module "observability" {
  source = "./modules/observability"

  name_prefix        = local.name_prefix
  log_retention_days = var.log_retention_days
}

module "catalog_service" {
  source = "./modules/ecs_service"

  name                      = "${local.name_prefix}-catalog"
  cluster_id                = module.ecs_cluster.cluster_id
  cluster_name              = module.ecs_cluster.cluster_name
  cpu                       = var.backend_cpu
  memory                    = var.backend_memory
  execution_role_arn        = module.iam.execution_role_arn
  task_role_arn             = module.iam.task_role_arn
  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [module.security_groups.backend_security_group_id]
  desired_count             = var.desired_count
  aws_region                = var.aws_region
  enable_execute_command    = var.enable_execute_command && !local.is_prod
  service_connect_namespace = module.ecs_cluster.namespace_arn
  service_connect_log_group = local.log["sc-catalog"]
  service_connect_server = {
    port_name      = "catalog-http"
    discovery_name = local.catalog_dns
    dns_name       = local.catalog_dns
    port           = local.backend_port
  }
  tls_pca_arn            = module.pca.pca_arn
  tls_kms_key_arn        = module.pca.kms_key_arn
  tls_role_arn           = module.iam.service_connect_tls_role_arn
  enable_autoscaling     = var.enable_autoscaling
  autoscaling_min        = var.desired_count
  autoscaling_max        = var.autoscaling_max
  autoscaling_cpu_target = var.autoscaling_cpu_target

  container_definitions = jsonencode([{
    name      = "catalog"
    image     = "${module.ecr.repository_urls["catalog"]}:${var.image_tag}"
    essential = true
    portMappings = [{
      name          = "catalog-http"
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }]
    environment = [
      { name = "PORT", value = "8080" }
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "node -e \"fetch('http://127.0.0.1:8080/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 20
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.log["catalog"]
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "catalog"
      }
    }
  }])

  depends_on = [module.pca]
}

module "sales_service" {
  source = "./modules/ecs_service"

  name                      = "${local.name_prefix}-sales"
  cluster_id                = module.ecs_cluster.cluster_id
  cluster_name              = module.ecs_cluster.cluster_name
  cpu                       = var.backend_cpu
  memory                    = var.backend_memory
  execution_role_arn        = module.iam.execution_role_arn
  task_role_arn             = module.iam.task_role_arn
  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [module.security_groups.backend_security_group_id]
  desired_count             = var.desired_count
  aws_region                = var.aws_region
  enable_execute_command    = var.enable_execute_command && !local.is_prod
  service_connect_namespace = module.ecs_cluster.namespace_arn
  service_connect_log_group = local.log["sc-sales"]
  service_connect_server = {
    port_name      = "sales-http"
    discovery_name = local.sales_dns
    dns_name       = local.sales_dns
    port           = local.backend_port
  }
  tls_pca_arn            = module.pca.pca_arn
  tls_kms_key_arn        = module.pca.kms_key_arn
  tls_role_arn           = module.iam.service_connect_tls_role_arn
  enable_autoscaling     = var.enable_autoscaling
  autoscaling_min        = var.desired_count
  autoscaling_max        = var.autoscaling_max
  autoscaling_cpu_target = var.autoscaling_cpu_target

  container_definitions = jsonencode([{
    name      = "sales"
    image     = "${module.ecr.repository_urls["sales"]}:${var.image_tag}"
    essential = true
    portMappings = [{
      name          = "sales-http"
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }]
    environment = [
      { name = "PORT", value = "8080" },
      { name = "CATALOG_BASE_URL", value = "http://${local.catalog_dns}:${local.backend_port}" },
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "node -e \"fetch('http://127.0.0.1:8080/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 20
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.log["sales"]
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "sales"
      }
    }
  }])

  depends_on = [module.pca, module.catalog_service]
}

module "ui_service" {
  source = "./modules/ecs_service"

  name                              = "${local.name_prefix}-ui"
  cluster_id                        = module.ecs_cluster.cluster_id
  cluster_name                      = module.ecs_cluster.cluster_name
  cpu                               = var.ui_cpu
  memory                            = var.ui_memory
  execution_role_arn                = module.iam.execution_role_arn
  task_role_arn                     = module.iam.task_role_arn
  subnet_ids                        = module.vpc.private_subnet_ids
  security_group_ids                = [module.security_groups.ui_security_group_id]
  desired_count                     = var.desired_count
  aws_region                        = var.aws_region
  enable_execute_command            = var.enable_execute_command && !local.is_prod
  health_check_grace_period_seconds = 60
  load_balancer = {
    target_group_arn = module.alb.target_group_arn
    container_name   = "ui"
    container_port   = 80
  }
  service_connect_namespace = module.ecs_cluster.namespace_arn
  service_connect_log_group = local.log["sc-ui"]
  service_connect_server    = null
  enable_autoscaling        = var.enable_autoscaling
  autoscaling_min           = var.desired_count
  autoscaling_max           = var.autoscaling_max
  autoscaling_cpu_target    = var.autoscaling_cpu_target

  container_definitions = jsonencode([{
    name      = "ui"
    image     = "${module.ecr.repository_urls["ui"]}:${var.image_tag}"
    essential = true
    portMappings = [{
      name          = "ui-http"
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
      appProtocol   = "http"
    }]
    environment = [
      { name = "CATALOG_HOST", value = local.catalog_dns },
      { name = "CATALOG_PORT", value = tostring(local.backend_port) },
      { name = "SALES_HOST", value = local.sales_dns },
      { name = "SALES_PORT", value = tostring(local.backend_port) },
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "wget -q -O- http://127.0.0.1/health >/dev/null 2>&1 || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.log["ui"]
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ui"
      }
    }
  }])

  depends_on = [module.catalog_service, module.sales_service, module.alb, module.pca]
}
