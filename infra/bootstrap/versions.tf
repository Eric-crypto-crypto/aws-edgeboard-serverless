terraform {
  # Terraform 本体版本：1.10+ 才支持 S3 原生锁（use_lockfile）
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # ~> 6.0 表示：允许 6.x 的任何版本，但不会自动升级到 7.0
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"

  # 给本代码创建的所有资源自动打上标签，方便在账单里按项目筛选费用
  default_tags {
    tags = {
      Project   = "aws-edgeboard-serverless"
      ManagedBy = "terraform"
    }
  }
}
