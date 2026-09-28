# sns

Alarm notification topic.

**Secure by default:**
- KMS-encrypted with a required CMK.
- The topic policy lets only the named AWS services publish, scoped by `aws:SourceAccount`, and denies non-TLS publishes.

**Gotcha:** the CMK's key policy must also grant each publishing service `kms:GenerateDataKey*`/`kms:Decrypt` (see `modules/kms` `service_principals`). Without it, alarms change state but the notification is silently dropped.

**Inputs that relax it:** `publisher_service_principals`.
