variable "account_id" {
  description = "Account this env deploys to."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account id."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "env" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod."
  }
}

variable "owner" {
  description = "Owner tag."
  type        = string
}

variable "github_repo" {
  description = "owner/name of the repo whose workflows assume the CI roles."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
}

variable "private_subnets" {
  description = "Map of AZ => private subnet CIDR (at least two)."
  type        = map(string)
}

variable "interface_endpoint_services" {
  description = "Interface endpoints to create: only the services workloads call."
  type        = set(string)
}
