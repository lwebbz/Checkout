variable "name" {
  description = "Name prefix for the VPC and its resources."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && tonumber(split("/", var.cidr_block)[1]) <= 24
    error_message = "cidr_block must be a valid IPv4 CIDR of /24 or larger."
  }
}

variable "private_subnets" {
  description = "Private subnets, one per AZ: map of AZ name => CIDR. At least two AZs."
  type        = map(string)

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "At least two private subnets in two AZs are required."
  }

  validation {
    condition     = alltrue([for c in values(var.private_subnets) : can(cidrhost(c, 0))])
    error_message = "Every subnet CIDR must be a valid IPv4 CIDR."
  }
}

variable "kms_key_arn" {
  description = "CMK for the flow log and resolver query log groups."
  type        = string
}

variable "log_retention_in_days" {
  description = "Retention for flow logs and resolver query logs."
  type        = number
  default     = 365 # floor enforced by modules/cloudwatch
}

variable "flow_logs_enabled" {
  description = "VPC Flow Logs to CloudWatch."
  type        = bool
  default     = true
}

variable "resolver_query_logs_enabled" {
  description = "Route 53 Resolver query logging to CloudWatch."
  type        = bool
  default     = true
}
