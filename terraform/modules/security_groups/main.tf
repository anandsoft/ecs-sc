variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "backend_port" { type = number }

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "Internet to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "UI View"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ui.id]
  }

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_security_group" "ui" {
  name        = "${var.name_prefix}-ui"
  description = "UI tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS for ECR, logs, Service Connect TLS control plane"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-ui" }
}

resource "aws_security_group_rule" "ui_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.ui.id
  source_security_group_id = aws_security_group.alb.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  description              = "ALB to UI"
}

resource "aws_security_group" "backend" {
  name        = "${var.name_prefix}-backend"
  description = "Catalog and sales tasks"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS for ECR, logs, PCA, Secrets Manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-backend" }
}

resource "aws_security_group_rule" "backend_from_ui" {
  type                     = "ingress"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.ui.id
  from_port                = var.backend_port
  to_port                  = var.backend_port
  protocol                 = "tcp"
  description              = "UI Envoy to catalog/sales Service Connect"
}

resource "aws_security_group_rule" "ui_to_backend" {
  type                     = "egress"
  security_group_id        = aws_security_group.ui.id
  source_security_group_id = aws_security_group.backend.id
  from_port                = var.backend_port
  to_port                  = var.backend_port
  protocol                 = "tcp"
  description              = "UI to catalog/sales"
}

resource "aws_security_group_rule" "backend_from_backend" {
  type                     = "ingress"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.backend.id
  from_port                = var.backend_port
  to_port                  = var.backend_port
  protocol                 = "tcp"
  description              = "Sales Envoy to catalog Service Connect"
}

resource "aws_security_group_rule" "backend_to_backend" {
  type                     = "egress"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.backend.id
  from_port                = var.backend_port
  to_port                  = var.backend_port
  protocol                 = "tcp"
  description              = "Sales to catalog"
}

output "alb_security_group_id" { value = aws_security_group.alb.id }
output "ui_security_group_id" { value = aws_security_group.ui.id }
output "backend_security_group_id" { value = aws_security_group.backend.id }
