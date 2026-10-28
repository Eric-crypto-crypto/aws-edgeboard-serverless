provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Project     = "aws-edgeboard-serverless"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront 只从 us-east-1 读取 ACM 证书
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "aws-edgeboard-serverless"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
