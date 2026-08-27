variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile. Empty uses the default credential chain."
  type        = string
  default     = ""
}

variable "project_name" {
  type    = string
  default = "ecs-sc"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "desired_count" {
  description = "Minimum tasks per service (also autoscaling min)."
  type        = number
  default     = 3
}

variable "autoscaling_max" {
  type    = number
  default = 9
}

variable "autoscaling_cpu_target" {
  type    = number
  default = 70
}

variable "enable_autoscaling" {
  type    = bool
  default = true
}

variable "ui_cpu" {
  type    = number
  default = 512
}

variable "ui_memory" {
  type    = number
  default = 1024
}

variable "backend_cpu" {
  type    = number
  default = 512
}

variable "backend_memory" {
  type    = number
  default = 1024
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "nat_gateway_ha" {
  type    = bool
  default = true
}

variable "container_insights" {
  type    = bool
  default = true
}

variable "enable_execute_command" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "acm_certificate_arn" {
  description = "Optional ACM cert for HTTPS on the ALB. Empty keeps HTTP :80."
  type        = string
  default     = ""
}
