# Data source: read-only lookup of the current account ID
data "aws_caller_identity" "current" {}

locals {
  # S3 bucket names are global; the account ID suffix avoids collisions
  bucket_name = "edgeboard-tfstate-${data.aws_caller_identity.current.account_id}"
}

# 1. The bucket itself
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # Safety catch: keep an accidental destroy from deleting the state bucket
  lifecycle {
    prevent_destroy = true
  }
}

# 2. Versioning (lets us roll back a corrupted state file)
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Block all public access (all four settings on)
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. Bucket policy: deny any request not made over HTTPS
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  # Apply the public access block first so the two don't modify the bucket concurrently
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}
