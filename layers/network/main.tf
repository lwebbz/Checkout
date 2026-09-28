locals {
  prefix       = "${var.project}-${var.env}"
  state_bucket = "${var.account_id}-tfstate-${var.region}"
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

module "vpc" {
  source = "../../modules/private-vpc"

  name                     = local.prefix
  cidr_block               = var.vpc_cidr
  private_subnets          = var.private_subnets
  kms_key_arn              = data.terraform_remote_state.base.outputs.kms_key_arn
  permissions_boundary_arn = data.terraform_remote_state.iam.outputs.workload_boundary_arn
}

# No source SGs here: the workload SGs live in the app layer, which adds its
# own ingress rules to the exported endpoint SG.
module "endpoints" {
  source = "../../modules/vpc-endpoints"

  name       = local.prefix
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  services   = var.interface_endpoint_services
}

resource "aws_route53_zone" "internal" {
  #checkov:skip=CKV2_AWS_38:DNSSEC signing isn't supported for private hosted zones.
  #checkov:skip=CKV2_AWS_39:Query logging for private zones is the VPC's Resolver query logging (enabled in private-vpc).
  name    = data.terraform_remote_state.base.outputs.internal_domain
  comment = "${local.prefix} private zone: resolvable only inside the VPC"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}
