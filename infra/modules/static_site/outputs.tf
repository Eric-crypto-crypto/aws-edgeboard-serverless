output "bucket_name" {
  description = "上传前端文件的目标桶"
  value       = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  description = "创建缓存失效时使用"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "CloudFront 默认域名，例如 dxxxx.cloudfront.net"
  value       = aws_cloudfront_distribution.this.domain_name
}
