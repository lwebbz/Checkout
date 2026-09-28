# vpc-endpoints

Interface (PrivateLink) endpoints, sharing one dedicated security group.

**Secure by default:**
- Private DNS is on, so SDKs use the endpoints with no code change.
- The dedicated SG has no rules until you allow a source SG, and then only HTTPS/443 from that SG. There are no CIDR sources and no egress rules.
- Rules are standalone resources, so a consuming state can add its own without drift.

**Inputs that relax it:** `endpoint_policy_json` (tightens it; the default is the AWS full-access policy).

Cost: ~$0.01/h per endpoint per AZ, plus data processing.
