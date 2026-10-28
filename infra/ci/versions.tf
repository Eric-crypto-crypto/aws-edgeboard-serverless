terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "edgeboard-tfstate-181851924026"
    key          = "ci/terraform.tfstate" # 和 dev 分开的独立台账
    region       = "ap-southeast-2"
    use_lockfile = true
    encrypt      = true
  }
}
