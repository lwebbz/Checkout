output "arn" {
  description = "Topic ARN (use as the alarm action)."
  value       = aws_sns_topic.this.arn
}
