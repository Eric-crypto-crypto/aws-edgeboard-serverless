terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  # Remote state in the bucket created by bootstrap (variables are not allowed here)
  backend "s3" {
    bucket       = "edgeboard-tfstate-181851924026"
    key          = "dev/terraform.tfstate" # One key per environment
    region       = "ap-southeast-2"
    use_lockfile = true # Native S3 locking
    encrypt      = true
  }
}
