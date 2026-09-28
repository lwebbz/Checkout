locals {
  prefix       = "${var.project}-${var.env}"
  state_bucket = "${var.account_id}-tfstate-${var.region}"
  role_arn     = "arn:aws:iam::${var.account_id}:role"
}

data "terraform_remote_state" "bootstrap" {
  backend = "s3"

  config = {
    bucket = local.state_bucket
    key    = "${var.project}/bootstrap/terraform.tfstate"
    region = var.region
  }
}

# --- Permissions boundary for workload roles ---------------------------------
# The most any role created by CI can ever do, whatever policies get attached
# later: write its logs, manage its Lambda ENIs, read config/secrets, decrypt.

data "aws_iam_policy_document" "workload_boundary" {
  #checkov:skip=CKV_AWS_111:Lambda VPC ENI actions don't support resource-level scoping; this is a ceiling, and each role's own policy grants less.
  #checkov:skip=CKV_AWS_356:Lambda VPC ENI actions don't support resource-level scoping; this is a ceiling, and each role's own policy grants less.
  statement {
    sid = "WriteLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
    ]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:log-group:*"]
  }

  statement {
    sid = "LambdaVpcNetworkInterfaces"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"]
  }

  # Workloads can only ever read this env's own config and secrets.
  statement {
    sid       = "ReadOwnConfig"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.region}:${var.account_id}:parameter/${local.prefix}-*"]
  }

  statement {
    sid       = "ReadOwnSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${local.prefix}/*"]
  }

  statement {
    sid       = "DecryptViaServices"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${var.region}:${var.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com", "secretsmanager.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = "${local.prefix}-workload-boundary"
  description = "Permissions boundary every CI-created role must carry"
  policy      = data.aws_iam_policy_document.workload_boundary.json
}

# --- ci-plan: PRs and main, read-only ----------------------------------------

data "aws_iam_policy_document" "ci_plan" {
  statement {
    sid       = "StateLockFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/${var.project}/${var.env}/*.tflock"]
  }

  statement {
    sid       = "StateEncryption"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [data.terraform_remote_state.bootstrap.outputs.state_kms_key_arn]
  }

  # Refreshing SecureString parameters and KMS-encrypted objects during plan.
  statement {
    sid       = "DecryptViaServices"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${var.region}:${var.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com", "s3.${var.region}.amazonaws.com", "secretsmanager.${var.region}.amazonaws.com"]
    }
  }

  # ReadOnlyAccess omits this, but refreshing aws_secretsmanager_secret_version
  # calls it. The plan role can already read these keys from state (sandbox
  # trade-off, README); with AWS Private CA there are no key secrets at all.
  statement {
    sid       = "RefreshOwnSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${local.prefix}/*"]
  }
}

module "ci_plan" {
  source = "../../modules/iam"

  name        = "${local.prefix}-ci-plan"
  description = "GitHub Actions terraform plan (pull requests and main)"
  github_oidc = {
    provider_arn = data.terraform_remote_state.bootstrap.outputs.github_oidc_provider_arn
    subjects = [
      "${var.github_oidc_subject_prefix}:pull_request",
      "${var.github_oidc_subject_prefix}:ref:refs/heads/main",
    ]
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  inline_policies     = { plan = data.aws_iam_policy_document.ci_plan.json }
}

# --- ci-apply: GitHub Environment <env> only ----------------------------------
# PowerUserAccess covers every non-IAM service. IAM is granted separately and
# only for roles that carry the workload boundary, so CI can't mint a role more
# powerful than the boundary, nor touch its own roles or the boundary itself.

data "aws_iam_policy_document" "ci_apply_iam" {
  statement {
    sid = "ManageBoundedRoles"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRolePolicy",
    ]
    resources = ["${local.role_arn}/${local.prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.workload_boundary.arn]
    }
  }

  statement {
    sid = "ReadAndTidyRoles"
    actions = [
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["${local.role_arn}/${local.prefix}-*"]
  }

  statement {
    sid       = "PassRolesToWorkloads"
    actions   = ["iam:PassRole"]
    resources = ["${local.role_arn}/${local.prefix}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com", "vpc-flow-logs.amazonaws.com"]
    }
  }

  statement {
    sid       = "ReadPolicies"
    actions   = ["iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions"]
    resources = ["*"]
  }

  statement {
    sid       = "ProtectCiRolesAndBoundary"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["${local.role_arn}/${local.prefix}-ci-*", aws_iam_policy.workload_boundary.arn]
  }

  # PowerUserAccess covers S3 and KMS: stop CI from unlocking or destroying the
  # state backend (reading and writing state objects stays allowed).
  statement {
    sid    = "ProtectStateBucket"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketOwnershipControls",
      "s3:DeleteObjectVersion",
    ]
    resources = ["arn:aws:s3:::${local.state_bucket}", "arn:aws:s3:::${local.state_bucket}/*"]
  }

  statement {
    sid    = "ProtectStateKey"
    effect = "Deny"
    actions = [
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:DisableKey",
      "kms:DisableKeyRotation",
      "kms:CreateGrant",
    ]
    resources = [data.terraform_remote_state.bootstrap.outputs.state_kms_key_arn]
  }

  statement {
    sid       = "NeverRemoveBoundaries"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary", "iam:PutRolePermissionsBoundary"]
    resources = ["*"]
  }
}

module "ci_apply" {
  source = "../../modules/iam"

  name        = "${local.prefix}-ci-apply"
  description = "GitHub Actions terraform apply (GitHub Environment ${var.env} only)"
  github_oidc = {
    provider_arn = data.terraform_remote_state.bootstrap.outputs.github_oidc_provider_arn
    subjects     = ["${var.github_oidc_subject_prefix}:environment:${var.env}"]
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  inline_policies     = { iam = data.aws_iam_policy_document.ci_apply_iam.json }
}
