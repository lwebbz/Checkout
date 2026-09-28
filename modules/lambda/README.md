# lambda

A VPC-attached Lambda (any zip-deployable managed runtime) with its own role, log group and alarms.

**Supported runtimes:** `runtime` is required and must be on the platform list: GA, Amazon Linux 2023, zip-deployable, and more than 6 months from deprecation. It currently allows Python 3.12-3.14, Node.js 22/24, Java 21/25, .NET 10, Ruby 3.3/3.4/4.0 and `provided.al2023` (Go, Rust). The list was reviewed on 2026-09-28 against the [AWS Lambda runtimes page](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html). Adding or removing a runtime is a deliberate module change.

**Secure by default:**
- VPC attachment is **mandatory**: subnets (≥2) and security groups are required inputs.
- The function gets its own execution role (via `modules/iam`), trusted only by Lambda in this account. Base permissions are its own log group's streams plus the VPC ENI actions, and nothing else. Everything the function itself needs comes from the caller's `policy_json`. An optional permissions boundary can be attached.
- A KMS-encrypted log group with required retention is pre-created (via `modules/cloudwatch`), with JSON log format.
- **No environment variables.** Runtime config and secrets come only from SSM Parameter Store and Secrets Manager. By convention, a function reads `/<function name>/config` (its name comes from the runtime's `AWS_LAMBDA_FUNCTION_NAME`), so the same package works in every env and nothing is configured on the function itself. Trade-off vs the more common "parameter name in an env var" pattern: the function-to-parameter link is a naming rule rather than explicit wiring, so renaming a function means renaming its parameter.
- arm64 (Graviton) by default; `architecture = "x86_64"` is an explicit opt-in for x86-only dependencies. Errors and Throttles alarms go to an SNS topic.

**Deliberately off:**
- X-Ray: an ALB has no X-Ray integration.
- Reserved concurrency: the new-account quota rejects any reservation.
- Code signing: a follow-up.

The reasons are inline as Checkov skips.
