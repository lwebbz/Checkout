internal_domain     = "internal-api-dev.internal"
client_common_names = ["smoke-test"]

admin_principal_arns = [
  "arn:aws:iam::328996808954:user/lawrence-admin",
]

# Same-day teardown
force_destroy_buckets          = true
secret_recovery_window_in_days = 0

# alert_emails lives in the gitignored base.local.tfvars
