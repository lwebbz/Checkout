# cloudwatch

CloudWatch log group.

**Secure by default:**
- A KMS key is **required**.
- Retention defaults to 365 days and can't go lower. Only CloudWatch-supported values of at least a year are accepted (PCI DSS 10.5.1 asks for 12 months of audit log history), and "never expire" is rejected.

**Inputs that relax it:** none. Callers can only keep logs longer.

**Cost note:** at real scale, a year of high-volume logs such as VPC flow logs in CloudWatch gets expensive. The production pattern is to ship them to the central log archive (S3 with lifecycle tiers) and keep CloudWatch retention short, which would mean an explicit, reviewed exception to this floor.
