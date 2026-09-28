vpc_cidr = "10.30.0.0/22"

private_subnets = {
  "eu-west-2a" = "10.30.0.0/24"
  "eu-west-2b" = "10.30.1.0/24"
  "eu-west-2c" = "10.30.2.0/24"
}

interface_endpoint_services = ["ssm", "secretsmanager"]
