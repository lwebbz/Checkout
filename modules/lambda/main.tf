module "log_group" {
  source = "../cloudwatch"

  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_in_days
  kms_key_arn       = var.kms_key_arn
}

data "aws_iam_policy_document" "base" {
  #checkov:skip=CKV_AWS_111:EC2 network-interface actions used by Lambda for VPC attachment don't support resource-level scoping.
  #checkov:skip=CKV_AWS_356:EC2 network-interface actions used by Lambda for VPC attachment don't support resource-level scoping.

  # Log group is pre-created by this module, so no logs:CreateLogGroup.
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${module.log_group.arn}:*"]
  }

  statement {
    sid = "VpcNetworkInterfaces"
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
}

# Base permissions plus the caller's, merged; statement ids keep them distinguishable.
data "aws_iam_policy_document" "execution" {
  source_policy_documents = compact([data.aws_iam_policy_document.base.json, var.policy_json])
}

module "role" {
  source = "../iam"

  name                     = var.name
  description              = "Execution role for the ${var.name} Lambda"
  trusted_services         = ["lambda.amazonaws.com"]
  permissions_boundary_arn = var.permissions_boundary_arn
  # One policy under a static key: for_each keys must be known at plan time,
  # and policy_json usually isn't (it references ARNs created in the same apply).
  inline_policies = { execution = data.aws_iam_policy_document.execution.json }
}

data "archive_file" "package" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/build/${var.name}.zip"
  excludes    = var.package_excludes
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_50:No X-Ray by decision: an ALB has no X-Ray integration, so tracing would stop at the function (README).
  #checkov:skip=CKV_AWS_116:DLQ applies to async invokes; failed probe runs are caught by the ProbeSuccess alarm instead.
  #checkov:skip=CKV_AWS_115:Reserved concurrency is opt-in: new accounts' 10-concurrency quota rejects any reservation.
  #checkov:skip=CKV_AWS_272:Code signing needs a signing profile and pipeline; noted as a follow-up.
  function_name                  = var.name
  description                    = var.description
  role                           = module.role.arn
  runtime                        = var.runtime
  handler                        = var.handler
  architectures                  = [var.architecture]
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  filename                       = data.archive_file.package.output_path
  source_code_hash               = data.archive_file.package.output_base64sha256
  reserved_concurrent_executions = var.reserved_concurrent_executions

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  logging_config {
    log_format = "JSON"
    log_group  = module.log_group.name
  }
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  count = var.alarm_topic_arn == null ? 0 : 1

  alarm_name          = "${var.name}-errors"
  alarm_description   = "Unhandled errors in ${var.name}."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.this.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "throttles" {
  count = var.alarm_topic_arn == null ? 0 : 1

  alarm_name          = "${var.name}-throttles"
  alarm_description   = "Throttled invocations of ${var.name}."
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  dimensions          = { FunctionName = aws_lambda_function.this.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
}
