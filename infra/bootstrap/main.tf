# 数据源（data）：只读取、不创建。这里用来获取当前账号 ID
data "aws_caller_identity" "current" {}

locals {
  # S3 桶名全球唯一，加上账号 ID 后基本不会和别人重名
  bucket_name = "edgeboard-tfstate-${data.aws_caller_identity.current.account_id}"
}

# 1. 桶本身
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # 保险栓：防止误执行 destroy 时把"台账柜"一起删掉
  lifecycle {
    prevent_destroy = true
  }
}

# 2. 开启版本控制（台账的时光机）
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 3. 服务端加密
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. 阻止一切公开访问（四个开关全开）
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. 桶策略：拒绝所有非 HTTPS 的请求
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

  # 先确保"阻止公开访问"配置完成，再写策略，避免两者同时修改桶时冲突
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}
