data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# Private-only by construction: this module has no internet gateway, NAT
# gateway or public subnet resources, so no caller can switch one on.
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true # needed for interface endpoint private DNS and the private hosted zone
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

# Take over the default SG and strip every rule, so nothing lands on it by accident.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-default-do-not-use" }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-private-${each.key}" }
}

# One route table: only the local route and the S3 gateway endpoint.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.name}-s3" }
}

# --- VPC Flow Logs -----------------------------------------------------------

module "flow_log_group" {
  source = "../cloudwatch"
  count  = var.flow_logs_enabled ? 1 : 0

  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.log_retention_in_days
  kms_key_arn       = var.kms_key_arn
}

data "aws_iam_policy_document" "flow_logs_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ec2:${local.region}:${local.account_id}:vpc-flow-log/*"]
    }
  }
}

data "aws_iam_policy_document" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${module.flow_log_group[0].arn}:*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  name                 = "${var.name}-flow-logs"
  assume_role_policy   = data.aws_iam_policy_document.flow_logs_trust.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  name   = "write-flow-logs"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs[0].json
}

resource "aws_flow_log" "this" {
  count = var.flow_logs_enabled ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = module.flow_log_group[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  max_aggregation_interval = 60

  tags = { Name = "${var.name}-flow-logs" }
}

# --- Route 53 Resolver query logs --------------------------------------------

module "resolver_log_group" {
  source = "../cloudwatch"
  count  = var.resolver_query_logs_enabled ? 1 : 0

  name              = "/vpc/${var.name}/resolver-query-logs"
  retention_in_days = var.log_retention_in_days
  kms_key_arn       = var.kms_key_arn
}

data "aws_iam_policy_document" "resolver_log_delivery" {
  count = var.resolver_query_logs_enabled ? 1 : 0

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${module.resolver_log_group[0].arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:*"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "resolver" {
  count = var.resolver_query_logs_enabled ? 1 : 0

  policy_name     = "${var.name}-resolver-query-logs"
  policy_document = data.aws_iam_policy_document.resolver_log_delivery[0].json
}

resource "aws_route53_resolver_query_log_config" "this" {
  count = var.resolver_query_logs_enabled ? 1 : 0

  name            = "${var.name}-resolver-query-logs"
  destination_arn = module.resolver_log_group[0].arn

  depends_on = [aws_cloudwatch_log_resource_policy.resolver]
}

resource "aws_route53_resolver_query_log_config_association" "this" {
  count = var.resolver_query_logs_enabled ? 1 : 0

  resolver_query_log_config_id = aws_route53_resolver_query_log_config.this[0].id
  resource_id                  = aws_vpc.this.id
}
