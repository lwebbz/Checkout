variable "name" {
  description = "Function name (also the role and log group name)."
  type        = string
}

variable "description" {
  description = "What the function does."
  type        = string
}

variable "source_dir" {
  description = "Directory zipped as the deployment package."
  type        = string
}

variable "package_excludes" {
  description = "Glob patterns left out of the zip (e.g. build caches, so they don't bloat the package or change its hash)."
  type        = list(string)
  default     = []
}

variable "handler" {
  description = "Handler, e.g. handler.lambda_handler."
  type        = string
}

variable "runtime" {
  description = "Lambda managed runtime. Platform-supported list: GA, Amazon Linux 2023, zip-deployable, and more than 6 months from deprecation (reviewed 2026-09-28 against the AWS Lambda runtimes page)."
  type        = string

  validation {
    condition = contains([
      "python3.14", "python3.13", "python3.12",
      "nodejs24.x", "nodejs22.x",
      "java25", "java21",
      "dotnet10",
      "ruby4.0", "ruby3.4", "ruby3.3",
      "provided.al2023",
    ], var.runtime)
    error_message = "runtime must be a platform-supported Lambda runtime (see modules/lambda/README.md). Deprecated, Amazon Linux 2 and preview runtimes are not allowed."
  }
}

variable "timeout" {
  description = "Timeout in seconds."
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Memory in MB."
  type        = number
  default     = 256
}

variable "architecture" {
  description = "arm64 (Graviton, ~20% cheaper) unless a dependency only ships for x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be arm64 or x86_64."
  }
}

variable "subnet_ids" {
  description = "Private subnets. VPC attachment is mandatory."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Attach the function to at least two subnets/AZs."
  }
}

variable "security_group_ids" {
  description = "Security groups for the function's ENIs."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) >= 1
    error_message = "At least one security group is required."
  }
}

variable "kms_key_arn" {
  description = "CMK for the function's log group."
  type        = string
}

variable "log_retention_in_days" {
  description = "Log retention."
  type        = number
  default     = 365 # floor enforced by modules/cloudwatch
}

variable "policy_json" {
  description = "The function's own least-privilege permissions (e.g. one SSM parameter, one secret). Logs and VPC ENI permissions are added by the module."
  type        = string
  default     = null
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary for the execution role."
  type        = string
  default     = null
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency. null = unreserved: new accounts often have a 10-concurrency quota, and AWS rejects any reservation that would leave fewer than 10 unreserved."
  type        = number
  default     = null
}

variable "alarm_topic_arn" {
  description = "SNS topic for the Errors/Throttles alarms. null skips the alarms."
  type        = string
  default     = null
}
