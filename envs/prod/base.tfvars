internal_domain     = "internal-api-prod.internal"
client_common_names = ["smoke-test"]

admin_principal_arns = [
  "arn:aws:iam::328996808954:user/lawrence-admin",
]

force_destroy_buckets          = false
secret_recovery_window_in_days = 30
