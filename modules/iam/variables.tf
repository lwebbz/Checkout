variable "name" {
  description = "Role name."
  type        = string
}

variable "description" {
  description = "What assumes the role and why."
  type        = string
}

variable "github_oidc" {
  description = "Trust GitHub Actions via OIDC. subjects are exact `sub` claims (e.g. repo:org/repo:environment:dev); no wildcards."
  type = object({
    provider_arn = string
    subjects     = list(string)
  })
  default = null

  validation {
    condition = var.github_oidc == null || (
      length(var.github_oidc.subjects) > 0 &&
      alltrue([for s in var.github_oidc.subjects : can(regex("^repo:[^*]+:[^*]+$", s))])
    )
    error_message = "github_oidc.subjects must be exact repo:<owner>/<repo>:<context> claims with no '*'."
  }
}

variable "trusted_services" {
  description = "Trust AWS service principals instead (e.g. lambda.amazonaws.com)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for s in var.trusted_services : endswith(s, ".amazonaws.com")])
    error_message = "trusted_services must be AWS service principals."
  }
}

variable "managed_policy_arns" {
  description = "Managed policies to attach."
  type        = set(string)
  default     = []
}

variable "inline_policies" {
  description = "Inline policies: map of name => policy JSON."
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary to attach, if any."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Max session length in seconds."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be 3600-43200 seconds."
  }
}
