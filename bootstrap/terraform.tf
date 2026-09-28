terraform {
  required_version = "~> 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.66"
    }
  }

  backend "s3" {
    bucket       = "328996808954-tfstate-eu-west-2"
    key          = "internal-api/bootstrap/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:eu-west-2:328996808954:key/6e610c9d-c475-43b3-9caf-6411a0a92039"
    use_lockfile = true
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = "shared"
      Layer       = "bootstrap"
      Owner       = var.owner
      ManagedBy   = "terraform"
      Repo        = var.github_repo
    }
  }
}
