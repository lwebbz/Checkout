data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

data "aws_iam_policy_document" "key" {
  #checkov:skip=CKV_AWS_109:Key policy, not an IAM policy: root delegation is the AWS default and "*" is scoped to this key.
  #checkov:skip=CKV_AWS_111:Key policy, not an IAM policy: root delegation is the AWS default and "*" is scoped to this key.
  #checkov:skip=CKV_AWS_356:Key policy, not an IAM policy: "*" as resource means this key only.

  # Delegate to IAM in this account; principals still need an IAM policy that
  # names this key. No kms:* is ever granted to a service or "*".
  statement {
    sid       = "EnableIAMPolicies"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = var.allow_cloudwatch_logs ? [1] : []

    content {
      sid = "AllowCloudWatchLogs"
      actions = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*",
      ]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = ["logs.${local.region}.amazonaws.com"]
      }

      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []

    content {
      sid       = "AllowServicePrincipals"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = var.service_principals
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.key.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}
