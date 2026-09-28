# kms

Customer-managed symmetric key with an alias.

**Secure by default:**
- Rotation always on (not configurable).
- The key policy only delegates to IAM in this account. Service access is opt-in, and each grant is scoped: CloudWatch Logs by log-group encryption context, other services by `aws:SourceAccount`.
- Services get `Decrypt`/`GenerateDataKey*` only, never `kms:*`.

**Inputs that relax it:** `deletion_window_in_days` (7-30), `allow_cloudwatch_logs`, `service_principals`.
