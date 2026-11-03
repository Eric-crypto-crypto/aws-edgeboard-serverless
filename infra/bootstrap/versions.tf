terraform {
  # Terraform 1.10+ is required for native S3 locking (use_lockfile)
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # ~> 6.0 allows any 6.x release but never upgrades to 7.0
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"

  # Tag every resource so costs can be filtered by project in billing
  default_tags {
    tags = {
      Project   = "aws-edgeboard-serverless"
      ManagedBy = "terraform"
    }
  }
}
