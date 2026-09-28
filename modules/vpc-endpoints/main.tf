data "aws_region" "current" {}

# No inline ingress/egress blocks: rules are separate resources so another state
# (the app layer) can add its own without the two fighting over the SG.
resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints"
  description = "Interface VPC endpoints: HTTPS in from workload SGs only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-endpoints" }
}

resource "aws_vpc_security_group_ingress_rule" "from_sources" {
  for_each = var.allowed_source_security_group_ids

  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = each.value
}

resource "aws_vpc_endpoint" "this" {
  for_each = var.services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  policy              = var.endpoint_policy_json

  tags = { Name = "${var.name}-${each.value}" }
}
