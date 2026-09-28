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

variable "github_oidc_subject_prefix" {
  description = "Start of the GitHub OIDC 'sub' claim for this repo. GitHub issues immutable subjects with owner and repo ids (repo:<owner>@<id>/<repo>@<id>), so a renamed or re-created repo can't inherit the trust. Read it with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub"
  type        = string

  validation {
    condition     = can(regex("^repo:[^*:]+$", var.github_oidc_subject_prefix))
    error_message = "github_oidc_subject_prefix must look like repo:<owner>@<id>/<repo>@<id> (no wildcards or colons)."
  }
}
