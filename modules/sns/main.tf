data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "this" {
  name              = var.name
  kms_master_key_id = var.kms_key_arn
}

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "AllowServicePublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]

    principals {
      type        = "Service"
      identifiers = var.publisher_service_principals
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]

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
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_sns_topic_subscription" "email" {
  for_each = var.email_subscriptions

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}
