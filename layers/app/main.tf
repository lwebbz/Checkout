locals {
  prefix       = "${var.project}-${var.env}"
  state_bucket = "${var.account_id}-tfstate-${var.region}"

  api_name   = "${local.prefix}-api"
  probe_name = "${local.prefix}-smoke-test"
  probe_cn   = "smoke-test" # the probe's client cert CN; its role name is ${prefix}-<cn>

  iam     = data.terraform_remote_state.iam.outputs
  base    = data.terraform_remote_state.base.outputs
  network = data.terraform_remote_state.network.outputs

  python_package_excludes = ["**/__pycache__/**", "**/*.pyc"]
}

data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.project}/${var.env}/iam/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.project}/${var.env}/base/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = local.state_bucket
    key    = "${var.project}/${var.env}/network/terraform.tfstate"
    region = var.region
  }
}

# --- Security groups ---------------------------------------------------------
# Terraform strips AWS's default allow-all egress from new SGs, so each SG
# below can only send what its explicit rules allow.

resource "aws_security_group" "api" {
  name        = local.api_name
  description = "API Lambda: HTTPS out to the VPC endpoints only"
  vpc_id      = local.network.vpc_id

  tags = { Name = local.api_name }
}

resource "aws_security_group" "probe" {
  name        = local.probe_name
  description = "Probe client: HTTPS out to the API ALB and the VPC endpoints only"
  vpc_id      = local.network.vpc_id

  tags = { Name = local.probe_name }
}

resource "aws_vpc_security_group_egress_rule" "api_to_endpoints" {
  security_group_id            = aws_security_group.api.id
  description                  = "SSM via interface endpoint"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = local.network.endpoints_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "probe_to_endpoints" {
  security_group_id            = aws_security_group.probe.id
  description                  = "SSM and Secrets Manager via interface endpoints"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = local.network.endpoints_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "probe_to_alb" {
  security_group_id            = aws_security_group.probe.id
  description                  = "HTTPS to the API ALB"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = module.alb.security_group_id
}

# The endpoint SG belongs to the network layer; these standalone rules are the
# app layer's share of it.
resource "aws_vpc_security_group_ingress_rule" "endpoints_from_workloads" {
  for_each = {
    api   = aws_security_group.api.id
    probe = aws_security_group.probe.id
  }

  security_group_id            = local.network.endpoints_security_group_id
  description                  = "HTTPS from ${each.key} Lambda"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = each.value
}

# --- Runtime config (read by each function from /<function name>/config) ----

resource "aws_ssm_parameter" "api_config" {
  name        = "/${local.api_name}/config"
  description = "API runtime config"
  type        = "SecureString"
  key_id      = local.base.kms_key_arn
  value = jsonencode({
    allowed_client_common_names = sort(tolist(var.allowed_client_common_names))
    max_message_length          = var.max_message_length
  })
}

resource "aws_ssm_parameter" "probe_config" {
  name        = "/${local.probe_name}/config"
  description = "Synthetic probe runtime config"
  type        = "SecureString"
  key_id      = local.base.kms_key_arn
  value = jsonencode({
    api_url                = "https://${local.base.api_hostname}/"
    client_cert_secret_arn = local.base.client_cert_secret_arns[local.probe_cn]
  })
}

# --- Lambdas -----------------------------------------------------------------

data "aws_iam_policy_document" "api" {
  statement {
    sid       = "ReadOwnConfig"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.api_config.arn]
  }

  statement {
    sid       = "DecryptConfig"
    actions   = ["kms:Decrypt"]
    resources = [local.base.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com"]
    }
  }
}

module "api" {
  source = "../../modules/lambda"

  name                     = local.api_name
  description              = "Internal echo API behind the mTLS ALB"
  source_dir               = "${path.module}/../../src/api"
  package_excludes         = local.python_package_excludes
  handler                  = "handler.lambda_handler"
  runtime                  = "python3.12"
  subnet_ids               = local.network.private_subnet_ids
  security_group_ids       = [aws_security_group.api.id]
  kms_key_arn              = local.base.kms_key_arn
  policy_json              = data.aws_iam_policy_document.api.json
  permissions_boundary_arn = local.iam.workload_boundary_arn
  alarm_topic_arn          = local.base.alarms_topic_arn
}

data "aws_iam_policy_document" "probe" {
  statement {
    sid       = "ReadOwnConfig"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.probe_config.arn]
  }

  statement {
    sid       = "ReadClientCert"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.base.client_cert_secret_arns[local.probe_cn]]
  }

  statement {
    sid       = "DecryptConfigAndSecret"
    actions   = ["kms:Decrypt"]
    resources = [local.base.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com", "secretsmanager.${var.region}.amazonaws.com"]
    }
  }
}

module "probe" {
  source = "../../modules/lambda"

  name                     = local.probe_name
  description              = "Synthetic mTLS probe: calls the API as an in-VPC client and emits ProbeSuccess/ProbeLatency"
  source_dir               = "${path.module}/../../src/smoke_test"
  package_excludes         = local.python_package_excludes
  handler                  = "handler.lambda_handler"
  runtime                  = "python3.12"
  timeout                  = 30
  subnet_ids               = local.network.private_subnet_ids
  security_group_ids       = [aws_security_group.probe.id]
  kms_key_arn              = local.base.kms_key_arn
  policy_json              = data.aws_iam_policy_document.probe.json
  permissions_boundary_arn = local.iam.workload_boundary_arn
  alarm_topic_arn          = local.base.alarms_topic_arn
}

# --- ALB + DNS ---------------------------------------------------------------

module "alb" {
  source = "../../modules/alb"

  name                              = local.api_name
  vpc_id                            = local.network.vpc_id
  subnet_ids                        = local.network.private_subnet_ids
  allowed_client_security_group_ids = [aws_security_group.probe.id]
  certificate_arn                   = local.base.server_certificate_arn
  trust_store_ca_bundle             = local.base.trust_store_ca_bundle
  target_lambda = {
    function_name = module.api.function_name
    arn           = module.api.arn
  }
  logs_bucket         = local.base.alb_logs.bucket
  logs_prefix         = local.base.alb_logs.prefix
  deletion_protection = var.alb_deletion_protection
  alarm_topic_arn     = local.base.alarms_topic_arn
}

resource "aws_route53_record" "api" {
  zone_id = local.network.private_zone_id
  name    = local.base.api_hostname
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = false
  }
}

# --- Synthetic probe schedule + health alarm ---------------------------------

resource "aws_cloudwatch_event_rule" "probe" {
  name                = local.probe_name
  description         = "Run the mTLS probe"
  schedule_expression = var.probe_schedule
}

resource "aws_cloudwatch_event_target" "probe" {
  rule = aws_cloudwatch_event_rule.probe.name
  arn  = module.probe.arn
}

resource "aws_lambda_permission" "probe_schedule" {
  statement_id  = "AllowEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = module.probe.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.probe.arn
}

# A retried probe would blur the metric; the next scheduled run is the retry.
resource "aws_lambda_function_event_invoke_config" "probe" {
  function_name          = module.probe.function_name
  maximum_retry_attempts = 0
}

# Primary health signal: the whole DNS -> mTLS -> ALB -> Lambda path.
resource "aws_cloudwatch_metric_alarm" "probe" {
  alarm_name          = "${local.probe_name}-failing"
  alarm_description   = "The synthetic mTLS probe failed (or stopped reporting) in 2 of the last 3 periods. Check the probe's log for which check failed."
  namespace           = "InternalApi/Probe"
  metric_name         = "ProbeSuccess"
  dimensions          = { FunctionName = module.probe.function_name }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching" # silence means the probe itself is broken
  alarm_actions       = [local.base.alarms_topic_arn]
  ok_actions          = [local.base.alarms_topic_arn]
}
