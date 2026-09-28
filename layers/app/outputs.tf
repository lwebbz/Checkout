output "api_url" {
  description = "API URL (resolvable only inside the VPC)."
  value       = "https://${local.base.api_hostname}/"
}

output "probe_function_name" {
  description = "Invoke this for on-demand evidence: aws lambda invoke --function-name <name> out.json"
  value       = module.probe.function_name
}

output "api_log_group" {
  description = "API Lambda log group (structured request logs)."
  value       = module.api.log_group_name
}

output "probe_log_group" {
  description = "Probe log group."
  value       = module.probe.log_group_name
}

output "alb_dns_name" {
  description = "AWS-assigned ALB name: publicly resolvable to private IPs (documented gap); clients use api_url."
  value       = module.alb.dns_name
}
