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

# CloudFront only reads ACM certificates from us-east-1
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
