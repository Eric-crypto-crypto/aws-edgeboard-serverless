output "bucket_name" {
  description = "Bucket that receives the frontend files"
  value       = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  description = "Used to create cache invalidations"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "Default CloudFront domain, e.g. dxxxx.cloudfront.net"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "site_url" {
  value = "https://${var.domain_name}"
}
