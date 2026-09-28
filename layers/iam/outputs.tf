output "workload_boundary_arn" {
  description = "Permissions boundary every CI-created role must carry."
  value       = aws_iam_policy.workload_boundary.arn
}

output "ci_plan_role_arn" {
  description = "Role for GitHub Actions plan jobs (set as the AWS_PLAN_ROLE_ARN repo variable)."
  value       = module.ci_plan.arn
}

output "ci_apply_role_arn" {
  description = "Role for GitHub Actions apply jobs in the <env> GitHub Environment."
  value       = module.ci_apply.arn
}
