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

variable "allowed_client_common_names" {
  description = "Client cert CNs the API authorises (the ALB authenticates any cert from the CA; this is the per-client allow-list)."
  type        = set(string)
}

variable "max_message_length" {
  description = "Longest accepted message, in characters."
  type        = number
  default     = 1024

  validation {
    condition     = var.max_message_length >= 1 && var.max_message_length <= 10000
    error_message = "max_message_length must be 1-10000."
  }
}

variable "alb_deletion_protection" {
  description = "Block ALB deletion (true in prod, false in dev for same-day teardown)."
  type        = bool
}

variable "probe_schedule" {
  description = "How often the synthetic probe runs."
  type        = string
  default     = "rate(5 minutes)"
}
