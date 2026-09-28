variable "name" {
  description = "ALB name; -ts and -fn are appended for the trust store and target group."
  type        = string

  validation {
    condition     = length(var.name) <= 29 && !startswith(var.name, "internal-")
    error_message = "name must be at most 29 characters (the trust store appends -ts) and can't start with \"internal-\" (reserved by AWS)."
  }
}

variable "vpc_id" {
  description = "VPC for the ALB and its security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets in at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "An ALB needs subnets in at least two AZs."
  }
}

variable "allowed_client_security_group_ids" {
  description = "Client SGs allowed to reach the listener on 443, as label => SG id. Labels are static keys, so SG ids can be unknown until apply."
  type        = map(string)
  default     = {}
}

variable "allowed_client_cidrs" {
  description = "Extra client CIDRs allowed on 443 (e.g. the VPC CIDR). Prefer SGs."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_client_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "allowed_client_cidrs must be valid CIDRs, never 0.0.0.0/0."
  }
}

variable "certificate_arn" {
  description = "ACM certificate for the HTTPS listener."
  type        = string
}

variable "trust_store_ca_bundle" {
  description = "S3 location of the CA bundle clients' certs must chain to."
  type = object({
    bucket         = string
    key            = string
    object_version = optional(string)
  })
}

variable "target_lambda" {
  description = "Lambda that serves every request."
  type = object({
    function_name = string
    arn           = string
  })
}

variable "logs_bucket" {
  description = "S3 bucket for access and connection logs (SSE-S3; ALB log delivery can't use SSE-KMS)."
  type        = string
}

variable "logs_prefix" {
  description = "Key prefix for this ALB's logs."
  type        = string
}

variable "deletion_protection" {
  description = "Block deletion of the ALB (true in prod)."
  type        = bool
  default     = true
}

variable "alarm_topic_arn" {
  description = "SNS topic for the 5XX and mTLS-negotiation alarms. null skips them."
  type        = string
  default     = null
}

variable "tls_negotiation_error_threshold" {
  description = "Failed TLS/mTLS handshakes per 5 minutes before alarming."
  type        = number
  default     = 5
}
