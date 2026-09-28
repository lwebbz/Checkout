variable "name" {
  description = "Key name; the alias becomes alias/<name>."
  type        = string
}

variable "description" {
  description = "What the key protects."
  type        = string
}

variable "deletion_window_in_days" {
  description = "Waiting period before the key is deleted."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be 7-30."
  }
}

variable "allow_cloudwatch_logs" {
  description = "Let CloudWatch Logs encrypt log groups in this account and region with the key."
  type        = bool
  default     = false
}

variable "service_principals" {
  description = "AWS services that encrypt/decrypt with the key on this account's behalf (e.g. cloudwatch.amazonaws.com so alarms can publish to an encrypted SNS topic). Scoped by aws:SourceAccount."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for s in var.service_principals : endswith(s, ".amazonaws.com")])
    error_message = "service_principals must be AWS service principals (*.amazonaws.com)."
  }
}
