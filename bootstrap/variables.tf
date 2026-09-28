variable "account_id" {
  description = "AWS account this bootstrap is allowed to run against."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account id."
  }
}

variable "region" {
  description = "Region for the state bucket and all layers."
  type        = string
  default     = "eu-west-2"
}

variable "project" {
  description = "Project name, used as the prefix for names and state keys."
  type        = string
  default     = "internal-api"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "project must be lowercase alphanumeric/hyphens, 3-21 chars."
  }
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository (owner/name) whose Actions workflows may assume the CI roles."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "github_repo must be in owner/name form."
  }
}

variable "admin_principal_arns" {
  description = "Human principals allowed to use the state bucket besides the CI roles (sandbox: the lawrence-admin IAM user)."
  type        = list(string)

  validation {
    condition     = length(var.admin_principal_arns) > 0 && alltrue([for a in var.admin_principal_arns : can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/", a))])
    error_message = "admin_principal_arns needs at least one IAM user or role ARN, otherwise the bucket policy locks everyone out."
  }
}

variable "noncurrent_state_retention_days" {
  description = "How long superseded state versions are kept for recovery."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_state_retention_days >= 30
    error_message = "Keep at least 30 days of state history."
  }
}
