locals {
  prefix          = "${var.project}-${var.env}"
  role_arn        = "arn:aws:iam::${var.account_id}:role"
  api_hostname    = "api.${var.internal_domain}"
  alb_logs_prefix = "alb"

  # Terraform itself (admin or CI) must be able to read the cert secrets back:
  # the provider refreshes secret versions on every plan.
  terraform_principals = concat(var.admin_principal_arns, ["${local.role_arn}/${local.prefix}-ci-*"])
}

# --- Encryption --------------------------------------------------------------

module "kms" {
  source = "../../modules/kms"

  name                  = local.prefix
  description           = "${local.prefix}: secrets, parameters, logs, alarms topic, artefacts bucket"
  allow_cloudwatch_logs = true
  # CloudWatch alarms publish to the KMS-encrypted SNS topic.
  service_principals = ["cloudwatch.amazonaws.com"]
}

# --- Buckets -----------------------------------------------------------------

module "artefacts_bucket" {
  source = "../../modules/s3"

  bucket_name   = "${local.prefix}-artefacts-${var.account_id}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = var.force_destroy_buckets
}

data "aws_iam_policy_document" "alb_log_delivery" {
  statement {
    sid       = "AllowAlbLogDelivery"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.prefix}-alb-logs-${var.account_id}/${local.alb_logs_prefix}/AWSLogs/${var.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    # The ALB lives in the app layer, so its exact ARN isn't known here.
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${var.region}:${var.account_id}:loadbalancer/app/${local.prefix}-*"]
    }
  }
}

# ALB access/connection log delivery only supports SSE-S3 (AWS constraint,
# see README Gaps), hence the explicit AES256 opt-in.
module "alb_logs_bucket" {
  source = "../../modules/s3"

  bucket_name                        = "${local.prefix}-alb-logs-${var.account_id}"
  sse_algorithm                      = "AES256"
  current_version_expiration_days    = 365
  noncurrent_version_expiration_days = 30
  additional_policy_json             = data.aws_iam_policy_document.alb_log_delivery.json
  force_destroy                      = var.force_destroy_buckets
}

# --- Alarm topic -------------------------------------------------------------

module "alarms_topic" {
  source = "../../modules/sns"

  name                = "${local.prefix}-alarms"
  kms_key_arn         = module.kms.key_arn
  email_subscriptions = var.alert_emails
}

# --- PKI (sandbox only; AWS Private CA in production) ------------------------

module "pki" {
  source = "../../modules/pki"

  organization        = "Internal API (${var.env})"
  ca_common_name      = "${local.prefix} sandbox CA"
  server_dns_names    = [local.api_hostname]
  client_common_names = var.client_common_names
}

# Server cert for the ALB listener. ACM keys can't be exported again.
resource "aws_acm_certificate" "server" {
  private_key       = module.pki.server_private_key_pem
  certificate_body  = module.pki.server_cert_pem
  certificate_chain = module.pki.ca_cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

# Public CA cert only: the ALB trust store's bundle.
resource "aws_s3_object" "ca_bundle" {
  bucket                 = module.artefacts_bucket.bucket_id
  key                    = "trust-store/ca-bundle.pem"
  content                = module.pki.ca_cert_pem
  content_type           = "application/x-pem-file"
  server_side_encryption = "aws:kms"
  kms_key_id             = module.kms.key_arn
}

# Client cert + key (+ CA, to verify the server) for each mTLS client.
module "client_cert_secret" {
  source   = "../../modules/secrets-manager"
  for_each = var.client_common_names

  name        = "${local.prefix}/mtls-client/${each.key}"
  description = "mTLS client certificate, key and CA for ${each.key}"
  kms_key_arn = module.kms.key_arn
  secret_string = jsonencode({
    cert_pem        = module.pki.clients[each.key].cert_pem
    private_key_pem = module.pki.clients[each.key].private_key_pem
    ca_cert_pem     = module.pki.ca_cert_pem
  })
  # Write-only values aren't diffed: derive the version from the (public)
  # certificate so a re-issued cert pushes a new secret version.
  secret_version          = parseint(substr(sha256(nonsensitive(module.pki.clients[each.key].cert_pem)), 0, 8), 16)
  reader_principal_arns   = concat(local.terraform_principals, ["${local.role_arn}/${local.prefix}-${each.key}"])
  recovery_window_in_days = var.secret_recovery_window_in_days
}

# Break-glass copy of the CA key, for issuing more client certs.
module "ca_key_secret" {
  source = "../../modules/secrets-manager"

  name                    = "${local.prefix}/pki/ca-private-key"
  description             = "Sandbox CA private key (break-glass)"
  kms_key_arn             = module.kms.key_arn
  secret_string           = module.pki.ca_private_key_pem
  secret_version          = parseint(substr(sha256(module.pki.ca_cert_pem), 0, 8), 16)
  reader_principal_arns   = local.terraform_principals
  recovery_window_in_days = var.secret_recovery_window_in_days
}
