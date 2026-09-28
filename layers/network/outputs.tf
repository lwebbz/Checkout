output "vpc_id" {
  description = "VPC id."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet ids."
  value       = module.vpc.private_subnet_ids
}

output "endpoints_security_group_id" {
  description = "Interface endpoint SG; the app layer adds ingress from its workload SGs."
  value       = module.endpoints.security_group_id
}

output "private_zone_id" {
  description = "Private hosted zone id."
  value       = aws_route53_zone.internal.zone_id
}
