variable "name_prefix" { type = string }
variable "tls_role_arn" { type = string }

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_acmpca_certificate_authority" "this" {
  type                            = "ROOT"
  usage_mode                      = "SHORT_LIVED_CERTIFICATE"
  permanent_deletion_time_in_days = 7

  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name = "${var.name_prefix}.local"
    }
  }

  tags = {
    AmazonECSManaged = "true"
  }
}

resource "aws_acmpca_certificate" "this" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.this.arn
  certificate_signing_request = aws_acmpca_certificate_authority.this.certificate_signing_request
  signing_algorithm           = "SHA256WITHRSA"
  template_arn                = "arn:${data.aws_partition.current.partition}:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 10
  }
}

resource "aws_acmpca_certificate_authority_certificate" "this" {
  certificate_authority_arn = aws_acmpca_certificate_authority.this.arn
  certificate               = aws_acmpca_certificate.this.certificate
  certificate_chain         = aws_acmpca_certificate.this.certificate_chain
}

resource "aws_kms_key" "tls" {
  description             = "Service Connect TLS keys for ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Root"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "ServiceConnectTls"
        Effect = "Allow"
        Principal = {
          AWS = var.tls_role_arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyPair",
          "kms:DescribeKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "tls" {
  name          = "alias/${var.name_prefix}-sc-tls"
  target_key_id = aws_kms_key.tls.key_id
}

output "pca_arn" { value = aws_acmpca_certificate_authority.this.arn }
output "kms_key_arn" { value = aws_kms_key.tls.arn }
