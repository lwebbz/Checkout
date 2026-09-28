data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trust" {
  dynamic "statement" {
    for_each = var.github_oidc == null ? [] : [var.github_oidc]

    content {
      sid     = "GitHubActionsOIDC"
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [statement.value.provider_arn]
      }

      condition {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:aud"
        values   = ["sts.amazonaws.com"]
      }

      # StringEquals, never StringLike: each subject is an exact repo + branch/environment/PR claim.
      condition {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:sub"
        values   = statement.value.subjects
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.trusted_services) == 0 ? [] : [1]

    content {
      sid     = "AWSServices"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "Service"
        identifiers = var.trusted_services
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  description          = var.description
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = var.permissions_boundary_arn
  max_session_duration = var.max_session_duration

  lifecycle {
    precondition {
      condition     = (var.github_oidc != null) != (length(var.trusted_services) > 0)
      error_message = "Set exactly one of github_oidc or trusted_services."
    }
  }
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}
