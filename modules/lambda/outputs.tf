output "function_name" {
  description = "Function name."
  value       = aws_lambda_function.this.function_name
}

output "arn" {
  description = "Function ARN."
  value       = aws_lambda_function.this.arn
}

output "role_arn" {
  description = "Execution role ARN."
  value       = module.role.arn
}

output "role_name" {
  description = "Execution role name."
  value       = module.role.name
}

output "log_group_name" {
  description = "Function log group."
  value       = module.log_group.name
}
