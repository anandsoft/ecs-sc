variable "name_prefix" { type = string }

data "aws_iam_policy_document" "ecs_tasks" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_infra" {
  statement {
    sid     = "AllowAccessToECSForInfrastructureManagement"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks.json
}

resource "aws_iam_role" "service_connect_tls" {
  name               = "${var.name_prefix}-sc-tls"
  assume_role_policy = data.aws_iam_policy_document.ecs_infra.json
}

resource "aws_iam_role_policy_attachment" "service_connect_tls" {
  role       = aws_iam_role.service_connect_tls.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForServiceConnectTransportLayerSecurity"
}

output "execution_role_arn" { value = aws_iam_role.execution.arn }
output "task_role_arn" { value = aws_iam_role.task.arn }
output "service_connect_tls_role_arn" { value = aws_iam_role.service_connect_tls.arn }
output "service_connect_tls_role_name" { value = aws_iam_role.service_connect_tls.name }
