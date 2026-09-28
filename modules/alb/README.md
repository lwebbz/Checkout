# alb

An internal Application Load Balancer that terminates mTLS in front of one Lambda.

**Secure by default, and not configurable:**
- `internal = true`. There's only an HTTPS :443 listener (no :80), using `ELBSecurityPolicy-TLS13-1-2-2021-06`.
- **mTLS `verify` mode** against a trust store built from the S3 CA bundle, with expired client certs rejected. Clients without a cert chaining to the CA fail the handshake and never reach Lambda.
- `drop_invalid_header_fields` and `desync_mitigation_mode = strictest`.
- A dedicated SG with 443 in from named client SGs (or explicit CIDRs, never `0.0.0.0/0`) and no egress.
- Access **and** connection logs are always on.
- The Lambda invoke permission is scoped to this target group.

**Alarms:** target 5XX, ELB 5XX, and `ClientTLSNegotiationErrorCount` (the only metric that sees rejected handshakes).

**Deliberately off:**
- The target health check: for Lambda it only proves "invocable". The synthetic probe is the health signal.
- WAF: see the README rationale.

**Constraints:**
- ALB log delivery supports **SSE-S3 only**, so `logs_bucket` must use `modules/s3` with `sse_algorithm = "AES256"`.
- The AWS-assigned DNS name is publicly resolvable (to private IPs), so clients use a private hosted zone name.

**Inputs that relax it:** `deletion_protection` (false in dev), `allowed_client_cidrs`.
