# private-vpc

Private-only VPC.

**Secure by default:**
- There's no internet gateway, NAT or public subnet anywhere in the module, so none can be switched on by an input.
- At least two AZs (validated). Public IPs are never mapped.
- The default security group is taken over and left with no rules.
- An S3 gateway endpoint is on the private route table.
- VPC Flow Logs (ALL traffic, 60s aggregation) and Route 53 Resolver query logs are **on by default**, going to KMS-encrypted log groups via the `cloudwatch` module.
- The flow-log role is scoped by `aws:SourceAccount`/`SourceArn`.

**Inputs that relax it:** `flow_logs_enabled`, `resolver_query_logs_enabled`.
