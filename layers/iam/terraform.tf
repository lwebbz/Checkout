terraform {
  required_version = "~> 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.66"
    }
  }

  # Partial config: bucket/key/kms_key_id come from envs/<env>/iam.tfbackend.
  backend "s3" {}
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.env
      Layer       = "iam"
      Owner       = var.owner
      ManagedBy   = "terraform"
      Repo        = var.github_repo
    }
  }
}
