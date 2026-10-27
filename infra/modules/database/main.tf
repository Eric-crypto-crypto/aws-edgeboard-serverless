resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # On-Demand 按请求计费

  # 主键：PK（区号）+ SK（区内编号）
  hash_key  = "PK"
  range_key = "SK"

  # 注意：只声明用作"键"的属性！
  attribute {
    name = "PK"
    type = "S" # S = String
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # 时间点恢复：可回滚到 35 天内任意一秒
  point_in_time_recovery {
    enabled = true
  }

  # TTL：expires_at 字段存 Unix 时间戳（秒），到期自动免费删除
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  deletion_protection_enabled = var.deletion_protection
}
