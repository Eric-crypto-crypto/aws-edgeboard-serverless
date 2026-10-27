output "state_bucket_name" {
  description = "Terraform 远程状态桶名称，后续 backend 配置要用"
  value       = aws_s3_bucket.tfstate.bucket
}
