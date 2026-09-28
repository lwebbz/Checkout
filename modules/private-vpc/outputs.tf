output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet ids, in AZ order."
  value       = [for az in sort(keys(aws_subnet.private)) : aws_subnet.private[az].id]
}

output "private_route_table_id" {
  description = "Route table shared by the private subnets."
  value       = aws_route_table.private.id
}

output "s3_gateway_endpoint_id" {
  description = "S3 gateway endpoint id."
  value       = aws_vpc_endpoint.s3.id
}

output "s3_prefix_list_id" {
  description = "Managed prefix list for S3, for SG egress rules to the gateway endpoint."
  value       = aws_vpc_endpoint.s3.prefix_list_id
}

output "flow_log_group_name" {
  description = "Flow log group, if enabled."
  value       = var.flow_logs_enabled ? module.flow_log_group[0].name : null
}

output "resolver_query_log_group_name" {
  description = "Resolver query log group, if enabled."
  value       = var.resolver_query_logs_enabled ? module.resolver_log_group[0].name : null
}
