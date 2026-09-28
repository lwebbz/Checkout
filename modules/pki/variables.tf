variable "organization" {
  description = "Subject O= for every certificate."
  type        = string
}

variable "ca_common_name" {
  description = "CA subject CN."
  type        = string
}

variable "server_dns_names" {
  description = "Server certificate SANs (the private hosted zone name clients use). The first is also the CN."
  type        = list(string)

  validation {
    condition     = length(var.server_dns_names) > 0
    error_message = "At least one server DNS name is required."
  }
}

variable "client_common_names" {
  description = "One client certificate is issued per CN. The CN is what the API's subject allow-list matches."
  type        = set(string)

  validation {
    condition     = length(var.client_common_names) > 0
    error_message = "At least one client is required."
  }
}

variable "ca_validity_hours" {
  description = "CA lifetime."
  type        = number
  default     = 2160 # 90 days

  validation {
    condition     = var.ca_validity_hours >= 24 && var.ca_validity_hours <= 8760
    error_message = "ca_validity_hours must be 24h-1y; a sandbox CA should be short-lived."
  }
}

variable "leaf_validity_hours" {
  description = "Server and client certificate lifetime."
  type        = number
  default     = 720 # 30 days

  validation {
    condition     = var.leaf_validity_hours >= 1 && var.leaf_validity_hours <= 2160
    error_message = "leaf_validity_hours must be 1h-90d."
  }
}

variable "early_renewal_hours" {
  description = "Re-issue leaves on apply when they are within this many hours of expiry."
  type        = number
  default     = 168 # 7 days
}
