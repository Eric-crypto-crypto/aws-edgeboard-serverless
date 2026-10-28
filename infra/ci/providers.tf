provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Project   = "aws-edgeboard-serverless"
      Component = "ci"
      ManagedBy = "terraform"
    }
  }
}
