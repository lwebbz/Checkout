variable "name" {
  description = "Log group name."
  type        = string
}

variable "retention_in_days" {
  description = "Retention period: at least a year (PCI DSS 10.5.1 audit history), never 'never expire'."
  type        = number
  default     = 365

  validation {
    condition = contains(
      [365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.retention_in_days
    )
    error_message = "retention_in_days must be a CloudWatch-supported value of at least 365 days (never-expire is not allowed)."
  }
}

variable "kms_key_arn" {
  description = "CMK encrypting the log group. Its key policy must allow CloudWatch Logs."
  type        = string
}
