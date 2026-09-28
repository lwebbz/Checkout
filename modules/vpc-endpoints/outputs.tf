output "security_group_id" {
  description = "Endpoint SG; add ingress rules from consumer SGs to it."
  value       = aws_security_group.endpoints.id
}

output "endpoint_ids" {
  description = "Map of service short name => endpoint id."
  value       = { for s, e in aws_vpc_endpoint.this : s => e.id }
}
