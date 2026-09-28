# s3

Private, versioned, encrypted bucket.

**Secure by default:**
- Public access block on and **not configurable**. ACLs are disabled (`BucketOwnerEnforced`).
- Versioning is always on, with a noncurrent-version expiry.
- SSE-KMS with a caller-supplied CMK and a bucket key.
- The bucket policy denies non-TLS access, any upload asking for a different encryption type, and (for KMS) a different key.
- `force_destroy` defaults to false.

**Inputs that relax it:**
- `sse_algorithm = "AES256"`: explicit opt-in, only for services that can't write SSE-KMS (ALB access/connection logs).
- `force_destroy`: dev only.
- `additional_policy_json`: extra statements, such as log delivery. The deny statements always apply on top.
