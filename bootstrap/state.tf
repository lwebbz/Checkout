# Remote state storage for every layer and env in this account.
# Self-contained raw resources on purpose: bootstrap must not depend on the
# modules/ it exists to serve.

locals {
  state_bucket_name = "${var.account_id}-tfstate-${var.region}"

  # Future CI roles (created by the iam layer) are named ${project}-${env}-ci-{plan,apply}.
  # A pattern means the bucket policy doesn't need re-applying when they appear.
  ci_role_arn_pattern = "arn:aws:iam::${var.account_id}:role/${var.project}-*-ci-*"
}

data "aws_iam_policy_document" "state_key" {
  #checkov:skip=CKV_AWS_109:Key policy, not an IAM policy: root delegation is the AWS default and "*" is scoped to this key.
  #checkov:skip=CKV_AWS_111:Key policy, not an IAM policy: root delegation is the AWS default and "*" is scoped to this key.
  #checkov:skip=CKV_AWS_356:Key policy, not an IAM policy: "*" as resource means this key only.
  # Standard key policy: delegate to IAM in this account. Who can use the key is
  # then decided by IAM policies plus the bucket policy below.
  statement {
    sid       = "EnableIAMPolicies"
    actions   = ["kms:*"]
    resources = ["*"] # in a key policy "*" means this key only

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "state" {
  description             = "${var.project} Terraform state encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.state_key.json
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.project}-tfstate"
  target_key_id = aws_kms_key.state.key_id
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:Access logging would need a second log bucket for a single-user sandbox; CloudTrail data events are the production control.
  #checkov:skip=CKV_AWS_144:Cross-region replication is out of scope for a same-day sandbox; versioning covers state recovery.
  #checkov:skip=CKV2_AWS_62:No consumers for S3 event notifications on the state bucket.
  bucket = local.state_bucket_name

  # Emptied by hand at the very end of teardown (see README), never by Terraform.
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_state_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Only the admin principal(s) and the CI roles may touch state, whatever their
  # IAM policies say. If this ever locks everyone out, the account root user can
  # still delete the bucket policy.
  statement {
    sid       = "DenyAllButAdminsAndCI"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = concat(var.admin_principal_arns, [local.ci_role_arn_pattern])
    }
  }

  # Writers must use this bucket's CMK. The backend sends the key ARN (not the
  # alias) in kms_key_id, because the condition compares the raw request header.
  statement {
    sid       = "DenyNonKmsEncryption"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEqualsIfExists"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid       = "DenyWrongKmsKey"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEqualsIfExists"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.state.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
