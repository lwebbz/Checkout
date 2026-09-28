variable "name" {
  description = "Name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the endpoints."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for endpoint ENIs (one per AZ)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Place endpoints in at least two subnets/AZs."
  }
}

variable "services" {
  description = "Interface endpoint services, by short name (e.g. ssm, secretsmanager). Only what workloads actually call."
  type        = set(string)

  validation {
    condition     = length(var.services) > 0
    error_message = "At least one service is required."
  }
}

variable "allowed_source_security_group_ids" {
  description = "SGs allowed to reach the endpoints on 443. May be empty: consumers in another state can add aws_vpc_security_group_ingress_rule on the exported SG instead."
  type        = set(string)
  default     = []
}

variable "endpoint_policy_json" {
  description = "Optional endpoint policy applied to every endpoint. null uses the AWS default (full access)."
  type        = string
  default     = null
}
