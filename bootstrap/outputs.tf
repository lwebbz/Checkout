output "state_bucket" {
  description = "S3 bucket holding Terraform state for every layer and env."
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "KMS key encrypting the state bucket."
  value       = aws_kms_key.state.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider, trusted by the CI roles in the iam layer."
  value       = aws_iam_openid_connect_provider.github.arn
}
