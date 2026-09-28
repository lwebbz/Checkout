# pki

**Sandbox-only** CA built with the `tls` provider: a self-signed CA, one server certificate and N client certificates.

**Secure by default:**
- ECDSA P-256 keys everywhere.
- Short, bounded lifetimes: CA ≤ 1 year (default 90 days) and leaves ≤ 90 days (default 30). Leaves re-issue on apply inside the early-renewal window.
- Key usages are separated: the server cert is `server_auth` only, client certs `client_auth` only, and the CA can sign certs/CRLs only.
- Private-key outputs are `sensitive`. Callers write them to Secrets Manager or ACM and never re-export them as root outputs.

**Known limit:** every private key is in Terraform state. The production replacement is AWS Private CA: the CA key stays in its HSM, ACM issues the server cert, and clients generate their own keys (ADR 0002).
