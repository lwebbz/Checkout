# Cross-layer contract (read via terraform_remote_state). ARNs and public
# material only: private keys are never outputs.

output "kms_key_arn" {
  description = "CMK for secrets, parameters, logs and the alarms topic."
  value       = module.kms.key_arn
}

output "alarms_topic_arn" {
  description = "SNS topic for every alarm."
  value       = module.alarms_topic.arn
}

output "alb_logs" {
  description = "ALB name, and the bucket/prefix it writes access and connection logs to (the bucket policy only allows this ALB and prefix)."
  value = {
    alb_name = local.alb_name
    bucket   = module.alb_logs_bucket.bucket_id
    prefix   = local.alb_logs_prefix
  }
}

output "server_certificate_arn" {
  description = "ACM-imported server certificate for the ALB listener."
  value       = aws_acm_certificate.server.arn
}

output "trust_store_ca_bundle" {
  description = "S3 location and version of the CA bundle for the ALB trust store."
  value = {
    bucket         = aws_s3_object.ca_bundle.bucket
    key            = aws_s3_object.ca_bundle.key
    object_version = aws_s3_object.ca_bundle.version_id
  }
}

output "client_cert_secret_arns" {
  description = "Secrets Manager ARN of each mTLS client's cert bundle, keyed by CN."
  value       = { for cn, s in module.client_cert_secret : cn => s.arn }
}

output "internal_domain" {
  description = "Private hosted zone domain (the network layer creates the zone)."
  value       = var.internal_domain
}

output "api_hostname" {
  description = "Name clients call; matches the server certificate SAN."
  value       = local.api_hostname
}
