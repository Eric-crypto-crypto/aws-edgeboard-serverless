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

  # 远程 state：存放在 bootstrap 创建的桶中（注意：这里不能使用变量）
  backend "s3" {
    bucket       = "edgeboard-tfstate-181851924026"
    key          = "dev/terraform.tfstate" # 每个环境一个独立的 key
    region       = "ap-southeast-2"
    use_lockfile = true # S3 原生锁
    encrypt      = true
  }
}
