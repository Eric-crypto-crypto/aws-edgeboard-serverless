resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # On-Demand: pay per request

  # Primary key: partition key (PK) + sort key (SK)
  hash_key  = "PK"
  range_key = "SK"

  # Only declare attributes that are used as keys!
  attribute {
    name = "PK"
    type = "S" # S = String
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Point-in-time recovery: restore to any second in the last 35 days
  point_in_time_recovery {
    enabled = true
  }

  # TTL: expires_at holds a Unix timestamp (seconds); expired items are deleted for free
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  deletion_protection_enabled = var.deletion_protection
}
