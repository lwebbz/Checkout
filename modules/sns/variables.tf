variable "name" {
  description = "Topic name."
  type        = string
}

variable "kms_key_arn" {
  description = "CMK encrypting the topic. Its key policy must allow every publishing service (e.g. cloudwatch.amazonaws.com)."
  type        = string
}

variable "publisher_service_principals" {
  description = "AWS services allowed to publish, scoped to this account."
  type        = list(string)
  default     = ["cloudwatch.amazonaws.com"]
}

variable "email_subscriptions" {
  description = "Email endpoints (each must confirm the subscription)."
  type        = set(string)
  default     = []
}
