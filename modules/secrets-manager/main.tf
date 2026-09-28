resource "aws_secretsmanager_secret" "this" {
  #checkov:skip=CKV2_AWS_57:Certificate material is rotated by re-issuing the cert, not by a rotation Lambda; production moves to AWS Private CA.
  name                    = var.name
  description             = var.description
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id                = aws_secretsmanager_secret.this.id
  secret_string_wo         = var.secret_string
  secret_string_wo_version = var.secret_version
}

# Resource-policy guard: whatever IAM grants elsewhere, only the named readers
# can read the value.
data "aws_iam_policy_document" "this" {
  statement {
    sid       = "DenyReadExceptNamedReaders"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = var.reader_principal_arns
    }
  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  secret_arn          = aws_secretsmanager_secret.this.arn
  policy              = data.aws_iam_policy_document.this.json
  block_public_policy = true
}
