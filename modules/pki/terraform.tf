terraform {
  required_version = "~> 1.11"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4"
    }
  }
}
