output "arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "AWS-assigned DNS name (publicly resolvable to private IPs; clients use the private hosted zone name instead)."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted zone id for alias records."
  value       = aws_lb.this.zone_id
}

output "arn_suffix" {
  description = "For CloudWatch dimensions."
  value       = aws_lb.this.arn_suffix
}

output "security_group_id" {
  description = "ALB security group."
  value       = aws_security_group.alb.id
}

output "listener_arn" {
  description = "HTTPS listener ARN."
  value       = aws_lb_listener.https.arn
}
