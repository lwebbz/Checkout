# iam

An IAM role for pipelines (GitHub OIDC) or AWS services.

**Secure by default:**
- The trust policy is built only from typed inputs, so there's no free-form trust JSON and no wildcard principals.
- GitHub OIDC trust requires `aud = sts.amazonaws.com` and matches `sub` with **`StringEquals`** against exact claims such as `repo:lwebbz/Checkout:environment:dev`. Wildcards are rejected by validation.
- Service trust is scoped by `aws:SourceAccount`.
- Optional permissions boundary. Max session defaults to 1 hour.

**Inputs that relax it:** `max_session_duration` (up to 12h), plus whatever policies you attach.
