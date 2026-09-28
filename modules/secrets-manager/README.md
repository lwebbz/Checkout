# secrets-manager

A secret with a resource policy.

**Secure by default:**
- A CMK is **required** (never the AWS-managed key).
- `GetSecretValue` is denied to everyone outside `reader_principal_arns`, and public policies are blocked.
- The value is written through the **write-only** `secret_string_wo`, so it isn't stored in this resource's state.
- The recovery window defaults to 30 days.

**Caveat:** write-only only keeps the value out of *this* resource's state. If the caller generates the value in Terraform (e.g. a `tls_private_key`), the generating resource still holds it in state. See ADR 0002.

**Inputs that relax it:** `recovery_window_in_days = 0` (dev, so destroy/re-create works).
