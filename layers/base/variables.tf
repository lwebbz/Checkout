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

variable "internal_domain" {
  description = "Private hosted zone domain; the API is api.<internal_domain>. The network layer reads it from this layer's outputs."
  type        = string
}

variable "client_common_names" {
  description = "One mTLS client cert is issued per CN."
  type        = set(string)
}

variable "admin_principal_arns" {
  description = "Human principals that may read the cert secrets (break-glass) alongside the Terraform roles."
  type        = list(string)
}

variable "alert_emails" {
  description = "Email subscribers to the alarm topic. Set in a gitignored *.local.tfvars file."
  type        = set(string)
  default     = []
}

variable "force_destroy_buckets" {
  description = "Allow terraform destroy to empty buckets. Dev only."
  type        = bool
  default     = false
}

variable "secret_recovery_window_in_days" {
  description = "0 in dev so destroy/re-create works; 30 in prod."
  type        = number
  default     = 30
}
