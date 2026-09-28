# Paved-road internal API entry point. Not configurable, by design:
#   internal = true, HTTPS only (no :80 listener), TLS 1.3/1.2 policy,
#   mTLS mode "verify" against the trust store, invalid headers dropped.

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Internal ALB: HTTPS in from named clients only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "from_client_sgs" {
  for_each = var.allowed_client_security_group_ids

  security_group_id            = aws_security_group.alb.id
  description                  = "HTTPS from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "from_client_cidrs" {
  for_each = var.allowed_client_cidrs

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from client CIDR"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

# No egress rules: the ALB invokes a Lambda target through the Lambda API, 
# not over the VPC network.

resource "aws_lb" "this" {
  #checkov:skip=CKV2_AWS_28:No WAF by design see README (WAF rationale).
  name                       = var.name
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = var.subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  desync_mitigation_mode     = "strictest"
  enable_deletion_protection = var.deletion_protection

  access_logs {
    enabled = true
    bucket  = var.logs_bucket
    prefix  = var.logs_prefix
  }

  connection_logs {
    enabled = true
    bucket  = var.logs_bucket
    prefix  = var.logs_prefix
  }
}

resource "aws_lb_trust_store" "this" {
  name                                     = "${var.name}-ts"
  ca_certificates_bundle_s3_bucket         = var.trust_store_ca_bundle.bucket
  ca_certificates_bundle_s3_key            = var.trust_store_ca_bundle.key
  ca_certificates_bundle_s3_object_version = var.trust_store_ca_bundle.object_version
}

resource "aws_lb_target_group" "lambda" {
  name        = "${var.name}-fn"
  target_type = "lambda"

  # A Lambda target health check only proves "invocable", fails open with one
  # target, and skips the listener/mTLS/DNS path. The synthetic probe is the
  # health signal instead.
  health_check {
    enabled = false
    # AWS still validates the timings on a disabled check, and the defaults
    # for Lambda targets (30s/30s) fail "interval must be greater than timeout".
    interval = 35
    timeout  = 30
  }
}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowInvokeFromALB"
  action        = "lambda:InvokeFunction"
  function_name = var.target_lambda.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = var.target_lambda.arn

  depends_on = [aws_lambda_permission.alb]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  mutual_authentication {
    mode                             = "verify"
    trust_store_arn                  = aws_lb_trust_store.this.arn
    ignore_client_certificate_expiry = false
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }
}

# --- Alarms ------------------------------------------------------------------

locals {
  alarms = var.alarm_topic_arn == null ? {} : {
    target-5xx = {
      metric      = "HTTPCode_Target_5XX_Count"
      threshold   = 0
      description = "The Lambda target returned 5XX responses."
    }
    elb-5xx = {
      metric      = "HTTPCode_ELB_5XX_Count"
      threshold   = 0
      description = "The ALB itself returned 5XX (e.g. Lambda invoke failures)."
    }
    tls-negotiation-errors = {
      metric      = "ClientTLSNegotiationErrorCount"
      threshold   = var.tls_negotiation_error_threshold
      description = "Failed TLS/mTLS handshakes: missing, expired or untrusted client certs, or scanning."
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = "AWS/ApplicationELB"
  metric_name         = each.value.metric
  dimensions          = { LoadBalancer = aws_lb.this.arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
}
