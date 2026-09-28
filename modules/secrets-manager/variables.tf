variable "name" {
  description = "Secret name."
  type        = string
}

variable "description" {
  description = "What the secret holds."
  type        = string
}

variable "kms_key_arn" {
  description = "CMK encrypting the secret (never the AWS-managed key)."
  type        = string
}

variable "secret_string" {
  description = "Secret value. Written via a write-only argument, so this resource doesn't store it in state (its source may still be in state; see the README)."
  type        = string
  sensitive   = true
}

variable "secret_version" {
  description = "Bump to push a new secret_string (write-only values aren't diffed)."
  type        = number
  default     = 1
}

variable "reader_principal_arns" {
  description = "The only principals allowed GetSecretValue, enforced by a resource-policy deny. Wildcards (e.g. role/app-*) are allowed."
  type        = list(string)

  validation {
    condition     = length(var.reader_principal_arns) > 0 && alltrue([for a in var.reader_principal_arns : can(regex("^arn:aws:iam::[0-9]{12}:", a))])
    error_message = "reader_principal_arns needs at least one IAM principal ARN in this account."
  }
}

variable "recovery_window_in_days" {
  description = "0 deletes immediately (dev, so destroy/re-create works); 7-30 in prod."
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 or 7-30."
  }
}
