variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "sse_algorithm" {
  description = "Default encryption. aws:kms (with kms_key_arn) unless a service can only write SSE-S3, e.g. ALB access logs; AES256 is an explicit opt-in."
  type        = string
  default     = "aws:kms"

  validation {
    condition     = contains(["aws:kms", "AES256"], var.sse_algorithm)
    error_message = "sse_algorithm must be aws:kms or AES256."
  }
}

variable "kms_key_arn" {
  description = "CMK for SSE-KMS. Required when sse_algorithm is aws:kms."
  type        = string
  default     = null

  validation {
    condition     = var.sse_algorithm != "aws:kms" || var.kms_key_arn != null
    error_message = "kms_key_arn is required when sse_algorithm is aws:kms."
  }
}

variable "force_destroy" {
  description = "Allow destroy of a non-empty bucket. Only for disposable dev estates."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  description = "Days before superseded object versions are deleted."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "noncurrent_version_expiration_days must be at least 1."
  }
}

variable "current_version_expiration_days" {
  description = "Days before current objects expire (e.g. log buckets). null keeps them."
  type        = number
  default     = null
}

variable "additional_policy_json" {
  description = "Extra bucket policy statements (e.g. service log delivery), merged with the built-in deny statements."
  type        = string
  default     = null
}
